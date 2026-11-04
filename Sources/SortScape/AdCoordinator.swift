import SwiftUI
import PuzzleCore

@MainActor
final class AdCoordinator: ObservableObject {
    enum Location: Equatable { case menu, playing, completed(Int) }
    @Published private(set) var enabled = false
    @Published private(set) var consentAllowed = false
    @Published private(set) var busy = false
    @Published private(set) var loading = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var message = "Ads are optional. All puzzles, hints, and normal undo work offline."
    @Published private(set) var readiness = 0
    var location: Location = .menu
    var isActive = true
    private let telemetry: Telemetry
    private let service: any AdService
    private let consent: any AdConsentService
    private let defaults: UserDefaults
    private let now: () -> Date
    let analytics: AdAnalytics
    private(set) var frequency: AdFrequencyManager
    private var progress: ProgressModel?
    private var initialized = false, started = false
    private var generation = 0
    private var pending: [String: AdReward] = [:]
    private var activeTicket: String?
    private var shownForTicket = false
    var rewardedAvailable: Bool { enabled && consentAllowed && consent.canRequestAds && !busy && service.rewardedReady && frequency.allowsRewarded(at: now()) }
    var hasPendingReward: Bool { !pending.isEmpty }

    init(service: any AdService = GoogleAdMobService(), consent: any AdConsentService = GoogleConsentService(), defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init, telemetry: Telemetry = .shared) {
        self.telemetry = telemetry
        self.service = service; self.consent = consent; self.defaults = defaults; self.now = now
        frequency = defaults.data(forKey: "ads.frequency.v1").flatMap { try? JSONDecoder().decode(AdFrequencyManager.self, from: $0) } ?? AdFrequencyManager()
        analytics = AdAnalytics(defaults: defaults)
        #if DEBUG
        privacyOptionsRequired = defaults.bool(forKey: "ads.privacyOptionsRequired") || consent.privacyOptionsRequired
        #endif
        service.event = { [weak self] in self?.handle($0) }
    }
    static func application() -> AdCoordinator {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"], UUID(uuidString: id) != nil {
            let mode = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_ADS"]
            if mode == "google" { return AdCoordinator(defaults: UserDefaults(suiteName: "SortScape.AdsTests.\(id)")!) }
            let mock = MockAdService(), consent = MockAdConsentService()
            if mode == "failure" { mock.loadSucceeds = false }
            if mode == "duplicate" { mock.duplicateCallbacks = true }
            if mode == "denied" { consent.canRequestAds = false }
            return AdCoordinator(service: mock, consent: consent, defaults: UserDefaults(suiteName: "SortScape.AdsTests.\(id)")!)
        }
        #endif
        return AdCoordinator()
    }
    func start(progress: ProgressModel, enabled: Bool) async {
        self.progress = progress
        if !started { started = true; frequency.beginSession(at: now()); saveFrequency(); analytics.session(at: now()) }
        if enabled && !defaults.bool(forKey: "ads.optOut") { await enableTestAds() }
    }
    func enableTestAds() async {
        #if DEBUG
        guard !busy, !loading else { return }
        // A private publisher application ID may configure UMP; ad UNIT IDs remain test-only.
        guard service is MockAdService || GoogleAdMobService.validApplicationID(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String) else {
            message = "The AdMob application identifier is missing or invalid. Ads remain off."; return
        }
        defaults.set(false, forKey: "ads.optOut")
        enabled = true; consentAllowed = false; generation += 1
        service.discardLoadedAds(); loading = true
        let consentGeneration = generation
        do {
            try await consent.update()
            guard consentGeneration == generation, enabled else { loading = false; return }
            privacyOptionsRequired = consent.privacyOptionsRequired
            consentAllowed = consent.canRequestAds
            if consentAllowed {
                if !initialized { await service.initialize(); initialized = true }
                guard consentGeneration == generation, enabled else { loading = false; return }
                message = "Google test ads enabled. Rewards require watching the ad; unavailable ads never block play."
            } else { message = "Ads are unavailable with the current privacy choices. Keep playing for free." }
        } catch {
            guard consentGeneration == generation, enabled else { loading = false; return }
            consentAllowed = false; privacyOptionsRequired = consent.privacyOptionsRequired
            message = "Privacy status could not be confirmed. Ads are off; your game works offline."
        }
        defaults.set(privacyOptionsRequired, forKey: "ads.privacyOptionsRequired")
        loading = false
        await preload()
        #endif
    }
    func disable() {
        defaults.set(true, forKey: "ads.optOut")
        consent.cancel()
        enabled = false; consentAllowed = false; generation += 1; service.discardLoadedAds(); readiness += 1
        message = "Ads disabled. Your rewards and normal gameplay are unchanged."
    }
    func privacyOptions() async {
        #if DEBUG
        guard !busy, !loading, privacyOptionsRequired else { return }
        consentAllowed = false; generation += 1; service.discardLoadedAds(); loading = true
        do { try await consent.privacyOptions(); consentAllowed = enabled && consent.canRequestAds; message = consentAllowed ? "Privacy choices updated." : "Ads disabled by privacy choices." }
        catch { consentAllowed = false; message = "Privacy choices could not be confirmed. Ads remain off." }
        privacyOptionsRequired = consent.privacyOptionsRequired; defaults.set(privacyOptionsRequired, forKey: "ads.privacyOptionsRequired"); loading = false; readiness += 1
        await preload()
        #endif
    }
    func preload() async {
        guard enabled, consentAllowed, consent.canRequestAds, !loading, !busy, isActive else { return }
        loading = true; defer { loading = false; readiness += 1 }
        let token = generation
        if !service.rewardedReady { await service.loadRewarded() }
        guard token == generation, enabled, consentAllowed, consent.canRequestAds else { service.discardLoadedAds(); return }
        if progress?.progress.purchases.removesAds != true, !service.interstitialReady { await service.loadInterstitial() }
        if token != generation { service.discardLoadedAds() }
    }
    func reward(_ reward: AdReward) async {
        guard let progress, rewardedAvailable, isActive else { message = "No ad is ready. Nothing was taken; keep playing or try again later."; return }
        switch reward {
        case .levelCoins(let id):
            guard location == .completed(id), progress.progress.isCompleted(id), !progress.progress.adRewards.hasBonus(for: id) else { message = "This world's bonus has already been collected or is unavailable."; return }
        case .hint, .undo: guard location == .playing else { return }
        }
        busy = true; defer { busy = false; activeTicket = nil; readiness += 1 }
        let ticket = UUID().uuidString
        activeTicket = ticket; shownForTicket = false
        var earned = false
        let shown = await service.presentRewarded { [weak self] in
            guard let self, !earned else { return }
            earned = true; self.analytics.increment("rewarded_completed")
            self.telemetry.emit(AnalyticsEvent(name: .rewardedCompleted), once: "earned.\(ticket)")
            self.pending[ticket] = reward; self.retryPendingRewards()
        }
        if !shown || !earned { message = "Ad closed or unavailable. No reward was earned and no currency was taken." }
        else if pending[ticket] == nil { message = "Reward saved. Thank you!" }
    }
    func retryPendingRewards() {
        guard let progress else { return }
        for (id, reward) in pending {
            do {
                if try progress.claimAdReward(id: id, reward: reward) { analytics.increment("reward_granted") }
                pending.removeValue(forKey: id)
            } catch { message = "Reward earned but could not be saved. Retry saving before leaving the app." }
        }
    }
    func canShowInterstitial(after completedLevel: Int) -> Bool {
        guard completedLevel.isMultiple(of: 10),
              let progress, location == .completed(completedLevel), progress.progress.isCompleted(completedLevel),
              isActive, enabled, consentAllowed, consent.canRequestAds, !busy, service.interstitialReady else { return false }
        return frequency.allowsInterstitial(completedLevels: progress.progress.bestMoves.count, betweenLevels: true,
                                            removesAds: progress.progress.purchases.removesAds, at: now())
    }

    /// Present from the completion sheet, while its presenter is still on screen.
    func betweenLevels(completedLevel: Int) async {
        guard canShowInterstitial(after: completedLevel) else { return }
        busy = true; activeTicket = UUID().uuidString; shownForTicket = false
        defer { busy = false; activeTicket = nil; readiness += 1 }
        _ = await service.presentInterstitial() // Never wait for a load or block progression on no fill.
    }
    func levelCompleted() {
        analytics.increment("level_completed")
        let day = Int(now().timeIntervalSince1970 / 86_400)
        analytics.increment(analytics.snapshot.adExposedDays.contains(day) ? "level_completed_ad_exposed_day" : "level_completed_adfree_day")
    }
    func foreground(_ active: Bool) {
        isActive = active
        if active { retryPendingRewards(); Task { await preload() } }
    }
    private func handle(_ event: AdEvent) {
        analytics.record(event, at: now())
        let metric: (AnalyticsEventName, AdFormat)? = switch event {
        case .load(let format): (.adLoad, format)
        case .loaded(let format): (.adLoaded, format)
        case .failed(let format): (.adFailed, format)
        case .dismissed(let format): (.adDismissed, format)
        default: nil
        }
        if let (name, format) = metric { telemetry.emit(AnalyticsEvent(name: name, parameters: ["ad_format": .text(format.rawValue)])) }
        if case .impression(.interstitial) = event, let ticket = activeTicket {
            telemetry.emit(AnalyticsEvent(name: .interstitialShown), once: "impression.\(ticket)")
        }
        if case .revenue(let format, let value, let currency) = event, let ticket = activeTicket, value.isFinite, value >= 0, value < 1_000_000,
           currency.count == 3, currency.utf8.allSatisfy({ (65...90).contains($0) }) {
            telemetry.emit(AnalyticsEvent(name: .adRevenue, parameters: ["ad_platform": .text("admob"), "ad_format": .text(format.rawValue), "value": .number(value), "currency": .text(currency)]), once: "revenue.\(ticket)")
        }
        if case .show(let format) = event, activeTicket != nil, !shownForTicket {
            if format == .rewarded, let ticket = activeTicket { telemetry.emit(AnalyticsEvent(name: .rewardedStarted), once: "show.\(ticket)") }
            shownForTicket = true; frequency.recordPresentation(interstitial: format == .interstitial, at: now()); saveFrequency()
        }
    }
    private func saveFrequency() { if let data = try? JSONEncoder().encode(frequency) { defaults.set(data, forKey: "ads.frequency.v1") } }
}
