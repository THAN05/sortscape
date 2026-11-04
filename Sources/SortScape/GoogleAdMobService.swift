import UIKit
@preconcurrency import GoogleMobileAds
@preconcurrency import UserMessagingPlatform

@MainActor
final class GoogleConsentService: AdConsentService {
    private var refreshed = false
    private var generation = 0
    func cancel() { generation += 1; refreshed = false }
    var canRequestAds: Bool { refreshed && ConsentInformation.shared.canRequestAds }
    var privacyOptionsRequired: Bool { ConsentInformation.shared.privacyOptionsRequirementStatus == .required }
    func update() async throws {
        refreshed = false; generation += 1; let token = generation
        let parameters = RequestParameters()
        try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
        guard token == generation else { throw CancellationError() }
        try await ConsentForm.loadAndPresentIfRequired(from: nil)
        guard token == generation else { throw CancellationError() }
        refreshed = true
    }
    func privacyOptions() async throws {
        refreshed = false; generation += 1; let token = generation
        try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
        guard token == generation else { throw CancellationError() }
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        guard token == generation else { throw CancellationError() }
        refreshed = true
    }
}

@MainActor
final class GoogleAdMobService: NSObject, AdService, FullScreenContentDelegate {
    // Official dedicated Google iOS test units. Production IDs are deliberately unsupported.
    static let sampleAppID = "ca-app-pub-3940256099942544~1458002511"
    static func validApplicationID(_ id: String?) -> Bool {
        guard let id else { return false }
        return id.range(of: "^ca-app-pub-[0-9]{16}~[0-9]{10}$", options: .regularExpression) != nil
    }
    #if DEBUG
    private static let rewardedUnit = "ca-app-pub-3940256099942544/1712485313"
    private static let interstitialUnit = "ca-app-pub-3940256099942544/4411468910"
    #endif
    var event: ((AdEvent) -> Void)?
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var rewardedLoaded: Date?, interstitialLoaded: Date?
    private var presentingAd: AnyObject?
    private var completion: CheckedContinuation<Bool, Never>?
    private var activeFormat: AdFormat?
    private var initialized = false
    private var generation = 0
    var rewardedReady: Bool { rewarded != nil && rewardedLoaded.map { Date().timeIntervalSince($0) < 3500 } == true }
    var interstitialReady: Bool { interstitial != nil && interstitialLoaded.map { Date().timeIntervalSince($0) < 3500 } == true }
    func initialize() async {
        #if DEBUG
        guard !initialized, Self.validApplicationID(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String) else { return }
        let configuration = MobileAds.shared.requestConfiguration
        configuration.setPublisherFirstPartyIDEnabled(false)
        configuration.coarseLocationCollectionEnabled = false
        configuration.publisherPrivacyPersonalizationState = .disabled
        configuration.maxAdContentRating = .general
        await MobileAds.shared.start()
        initialized = true
        #endif
    }
    private func request() -> Request {
        let request = Request(), extras = Extras()
        extras.additionalParameters = ["npa": "1", "rdp": "1"]
        request.register(extras)
        return request
    }
    func loadRewarded() async {
        #if DEBUG
        guard initialized else { return }
        event?(.load(.rewarded)); let token = generation
        do {
            let ad = try await RewardedAd.load(with: Self.rewardedUnit, request: request())
            guard token == generation else { return }
            ad.fullScreenContentDelegate = self; rewarded = ad; rewardedLoaded = Date(); event?(.loaded(.rewarded))
        } catch {
            #if DEBUG
            let failure = error as NSError
            print("Google test rewarded load failure: \(failure.domain) code \(failure.code)")
            #endif
            event?(.failed(.rewarded))
        }
        #endif
    }
    func loadInterstitial() async {
        #if DEBUG
        guard initialized else { return }
        event?(.load(.interstitial)); let token = generation
        do {
            let ad = try await InterstitialAd.load(with: Self.interstitialUnit, request: request())
            guard token == generation else { return }
            ad.fullScreenContentDelegate = self; interstitial = ad; interstitialLoaded = Date(); event?(.loaded(.interstitial))
        } catch {
            #if DEBUG
            let failure = error as NSError
            print("Google test interstitial load failure: \(failure.domain) code \(failure.code)")
            #endif
            event?(.failed(.interstitial))
        }
        #endif
    }
    func presentRewarded(earned: @escaping @MainActor () -> Void) async -> Bool {
        guard completion == nil, rewardedReady, let ad = rewarded, let root = Self.presenter() else { return false }
        do { try ad.canPresent(from: root) } catch { event?(.failed(.rewarded)); return false }
        rewarded = nil; activeFormat = .rewarded; presentingAd = ad
        return await withCheckedContinuation { continuation in
            completion = continuation
            ad.present(from: root) { [weak self] in self?.event?(.earned); earned() }
        }
    }
    func presentInterstitial() async -> Bool {
        guard completion == nil, interstitialReady, let ad = interstitial, let root = Self.presenter() else { return false }
        do { try ad.canPresent(from: root) } catch { event?(.failed(.interstitial)); return false }
        interstitial = nil; activeFormat = .interstitial; presentingAd = ad
        return await withCheckedContinuation { continuation in
            completion = continuation; ad.present(from: root)
        }
    }
    func discardLoadedAds() { generation += 1; rewarded = nil; interstitial = nil }
    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd) { if let activeFormat { event?(.show(activeFormat)) } }
    func adDidRecordImpression(_ ad: any FullScreenPresentingAd) { if let activeFormat { event?(.impression(activeFormat)) } }
    func ad(_ ad: any FullScreenPresentingAd, didRecordPaidEventWith value: AdValue) {
        if let activeFormat { event?(.revenue(activeFormat, value.value.doubleValue, value.currencyCode)) }
    }
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) { finish(success: true) }
    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { finish(success: false) }
    private func finish(success: Bool) {
        if let activeFormat { event?(success ? .dismissed(activeFormat) : .failed(activeFormat)) }
        let callback = completion; completion = nil; presentingAd = nil; activeFormat = nil
        callback?.resume(returning: success)
    }
    private static func presenter() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return nil }
        while let presented = root.presentedViewController { root = presented }
        return root.view.window != nil && !root.isBeingDismissed && !root.isBeingPresented ? root : nil
    }
}
