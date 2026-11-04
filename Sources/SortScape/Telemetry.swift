import Foundation
import Combine
import PuzzleCore

/// Closed event names; call sites supply bounded domain values, never player text or raw errors.
enum AnalyticsEventName: String, CaseIterable, Sendable {
    case sessionEnd = "session_end", tutorialStart = "tutorial_start", tutorialComplete = "tutorial_complete"
    case levelStart = "level_start", levelComplete = "level_complete", levelFail = "level_fail", levelRestart = "level_restart"
    case hintUsed = "hint_used", undoUsed = "undo_used", decorationUnlocked = "island_decoration_unlocked"
    case dailyStarted = "daily_challenge_started", dailyCompleted = "daily_challenge_completed"
    case rewardedOffered = "rewarded_ad_offered", rewardedStarted = "rewarded_ad_started", rewardedCompleted = "rewarded_ad_completed"
    case interstitialShown = "interstitial_ad_shown", purchaseStarted = "purchase_started", purchaseCompleted = "purchase_completed", purchaseFailed = "purchase_failed"
    case adLoad = "ad_load", adLoaded = "ad_loaded", adFailed = "ad_failed", adDismissed = "ad_dismissed"
    case currencyEarned = "virtual_currency_earned", currencySpent = "virtual_currency_spent", adRevenue = "ad_revenue_paid"
}
enum AnalyticsValue: Equatable, Sendable {
    case text(String), integer(Int), number(Double)
    var valid: Bool {
        switch self { case .text(let s): s.utf8.count <= 100
        case .integer: true
        case .number(let n): n.isFinite && abs(n) < 1e12 }
    }
}
struct AnalyticsEvent: Equatable, Sendable {
    let name: AnalyticsEventName
    var parameters: [String: AnalyticsValue] = [:]
    var valid: Bool { parameters.count <= 25 && parameters.allSatisfy { key, value in
        key.range(of: "^[a-z][a-z0-9_]{0,39}$", options: .regularExpression) != nil && value.valid
    } }
}
enum DiagnosticCode: Int, Sendable { case saveRead = 1, saveWrite, campaignLoad, storeConfiguration, hintSearchLimit, developmentProbe }
@MainActor protocol AnalyticsService: AnyObject {
    var available: Bool { get }
    func setCollection(analytics: Bool, crashes: Bool)
    func log(_ event: AnalyticsEvent)
    func record(_ code: DiagnosticCode)
}
@MainActor final class MockAnalyticsService: AnalyticsService {
    var available = true
    private(set) var events: [AnalyticsEvent] = []
    private(set) var errors: [DiagnosticCode] = []
    private(set) var analyticsEnabled = false, crashesEnabled = false
    func setCollection(analytics: Bool, crashes: Bool) { analyticsEnabled = analytics; crashesEnabled = crashes }
    func log(_ event: AnalyticsEvent) { if analyticsEnabled && event.valid { events.append(event) } }
    func record(_ code: DiagnosticCode) { if crashesEnabled { errors.append(code) } }
}

@MainActor final class Telemetry: ObservableObject {
    static let shared = Telemetry(service: FirebaseAnalyticsService(), defaults: applicationDefaults())
    private static func applicationDefaults() -> UserDefaults {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"], UUID(uuidString: id) != nil {
            return UserDefaults(suiteName: "SortScape.TelemetryTests.\(id)")!
        }
        #endif
        return .standard
    }
    @Published private(set) var analyticsEnabled: Bool
    @Published private(set) var crashesEnabled: Bool
    var available: Bool { service.available }
    private(set) var collectionRevision = 0
    private let service: any AnalyticsService
    private let defaults: UserDefaults
    private let clock: () -> TimeInterval
    private var sessionStarted: TimeInterval?
    private var levelsCompleted = 0
    private var emitted: Set<String> = []
    init(service: any AnalyticsService, defaults: UserDefaults, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.service = service; self.defaults = defaults; self.clock = clock
        analyticsEnabled = defaults.bool(forKey: "telemetry.analytics.v1")
        crashesEnabled = defaults.bool(forKey: "telemetry.crashes.v1")
        service.setCollection(analytics: analyticsEnabled, crashes: crashesEnabled)
    }
    func preferences(analytics: Bool, crashes: Bool) {
        if analyticsEnabled && !analytics { foreground(false) }
        if analyticsEnabled != analytics { collectionRevision += 1 }
        analyticsEnabled = analytics; crashesEnabled = crashes
        defaults.set(analytics, forKey: "telemetry.analytics.v1"); defaults.set(crashes, forKey: "telemetry.crashes.v1")
        service.setCollection(analytics: analytics, crashes: crashes)
        if analytics { foreground(true) } else { sessionStarted = nil; emitted.removeAll() }
    }
    func emit(_ event: AnalyticsEvent, once key: String? = nil) {
        guard analyticsEnabled, service.available, event.valid else { return }
        if let key { guard emitted.count < 10_000, emitted.insert(key).inserted else { return } }
        service.log(event)
    }
    private var diagnosed: Set<Int> = []
    func diagnose(_ code: DiagnosticCode) { if crashesEnabled && service.available && diagnosed.insert(code.rawValue).inserted { service.record(code) } }
    /// Firebase owns first_open/session_start/DAU. Our session is a foreground interval.
    func foreground(_ active: Bool) {
        guard analyticsEnabled, service.available else { return }
        if active {
            if sessionStarted == nil { sessionStarted = clock(); levelsCompleted = 0 }
        } else if let start = sessionStarted {
            emit(AnalyticsEvent(name: .sessionEnd, parameters: ["duration": .number(max(0, clock() - start)), "levels_completed": .integer(levelsCompleted)]))
            sessionStarted = nil
        }
    }
    func completedAttempt() { if sessionStarted != nil { levelsCompleted += 1 } }
    /// Source is a small domain label; ledger keys and StoreKit IDs never leave the device.
    func economy(before: PlayerProgress, after: PlayerProgress, reportPurchases: Bool = true) {
        for (id, tx) in after.economy.transactions where before.economy.transactions[id] == nil && tx.kind != .migration {
            let source = id.hasPrefix("iap.") ? "purchase" : (id.hasPrefix("ad") ? "rewarded_ad" : "gameplay")
            if tx.coins != 0 { emit(AnalyticsEvent(name: tx.coins > 0 ? .currencyEarned : .currencySpent, parameters: ["virtual_currency_name": .text("coins"), "value": .integer(abs(tx.coins)), "source": .text(source)])) }
            if tx.stars != 0 { emit(AnalyticsEvent(name: tx.stars > 0 ? .currencyEarned : .currencySpent, parameters: ["virtual_currency_name": .text("stars"), "value": .integer(abs(tx.stars)), "source": .text(source)])) }
        }
        for id in after.island.restored.subtracting(before.island.restored) {
            emit(AnalyticsEvent(name: .decorationUnlocked, parameters: ["decoration": .text(id.rawValue)]))
        }
        for (id, record) in after.purchases.fulfilled where reportPurchases && before.purchases.fulfilled[id] == nil && !record.revoked {
            // Verified, newly saved fulfillment only. Reconcile/restore never repeats this.
            emit(AnalyticsEvent(name: .purchaseCompleted, parameters: ["item": .text(record.item.rawValue)]))
        }
    }
}

/// A single visit can contain multiple attempts. Duration excludes pause/background time.
@MainActor final class LevelTelemetry {
    private let telemetry: Telemetry
    private let level: Level
    private let clock: () -> TimeInterval
    private var activeSince: TimeInterval?
    private var elapsed: TimeInterval = 0
    private var started = false, finished = false
    private var hints = 0, restarts = 0
    private var revision: Int
    init(level: Level, telemetry: Telemetry, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.level = level; self.telemetry = telemetry; self.clock = clock; revision = telemetry.collectionRevision
    }
    private func canTrack() -> Bool {
        if revision != telemetry.collectionRevision {
            revision = telemetry.collectionRevision
            activeSince = nil; elapsed = 0; started = false; finished = false; hints = 0; restarts = 0
        }
        guard telemetry.analyticsEnabled, telemetry.available else {
            activeSince = nil; elapsed = 0; started = false; hints = 0; restarts = 0
            return false
        }
        return true
    }
    private func parameters(moves: Int) -> [String: AnalyticsValue] {
        ["level_id": .integer(level.id), "difficulty": .text(level.tier.rawValue), "move_count": .integer(moves),
         "completion_time": .number(max(0, elapsed + (activeSince.map { clock() - $0 } ?? 0))), "hints_used": .integer(hints), "restarts": .integer(restarts)]
    }
    func resume() {
        guard canTrack(), !finished else { return }
        if !started { started = true; telemetry.emit(AnalyticsEvent(name: .levelStart, parameters: parameters(moves: 0))) }
        if activeSince == nil { activeSince = clock() }
    }
    func pause() { guard canTrack() else { return }; if let start = activeSince { elapsed += max(0, clock() - start); activeSince = nil } }
    func hint(moves: Int) { guard canTrack() else { return }; hints += 1; telemetry.emit(AnalyticsEvent(name: .hintUsed, parameters: parameters(moves: moves))) }
    func undo(moves: Int) { guard canTrack() else { return }; telemetry.emit(AnalyticsEvent(name: .undoUsed, parameters: parameters(moves: moves))) }
    func complete(moves: Int) {
        guard canTrack(), started, !finished else { return }; pause(); finished = true
        var values = parameters(moves: moves); values["stars_earned"] = .integer(level.stars(for: moves))
        telemetry.emit(AnalyticsEvent(name: .levelComplete, parameters: values)); telemetry.completedAttempt()
    }
    func restart(moves: Int) {
        guard canTrack() else { return }
        telemetry.emit(AnalyticsEvent(name: .levelRestart, parameters: parameters(moves: moves)))
        if !finished { abandon(moves: moves, reason: "restart") }
        restarts += 1; hints = 0; elapsed = 0; activeSince = nil; finished = false; started = false; resume()
    }
    func abandon(moves: Int, reason: String = "navigation") {
        guard canTrack(), started, !finished else { return }; pause(); finished = true
        var values = parameters(moves: moves); values["reason"] = .text(reason)
        telemetry.emit(AnalyticsEvent(name: .levelFail, parameters: values))
    }
}
