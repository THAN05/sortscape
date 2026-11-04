import XCTest
import SpriteKit
import PuzzleCore
@testable import SortScape

private final class TelemetrySave: PlayerSaveService, @unchecked Sendable {
    var value = PlayerProgress()
    var fails = false
    func load(campaign: LevelManager?) throws -> PlayerProgress { value }
    func save(_ progress: PlayerProgress) throws {
        if fails { throw CocoaError(.fileWriteUnknown) }
        value = progress
    }
}

@MainActor final class TelemetryTests: XCTestCase {
    private func fixture() -> (Telemetry, MockAnalyticsService, UserDefaults) {
        let defaults = UserDefaults(suiteName: "TelemetryTests.\(UUID())")!
        let service = MockAnalyticsService()
        return (Telemetry(service: service, defaults: defaults), service, defaults)
    }
    func testPrivacyDefaultsOptOutAndIndependentDiagnostics() {
        let (telemetry, service, defaults) = fixture()
        telemetry.emit(AnalyticsEvent(name: .levelStart)); telemetry.diagnose(.saveWrite)
        XCTAssertTrue(service.events.isEmpty); XCTAssertTrue(service.errors.isEmpty)
        telemetry.preferences(analytics: false, crashes: true)
        telemetry.diagnose(.saveWrite); telemetry.emit(AnalyticsEvent(name: .levelStart))
        XCTAssertEqual(service.errors.count, 1); XCTAssertTrue(service.events.isEmpty)
        telemetry.preferences(analytics: true, crashes: false)
        telemetry.emit(AnalyticsEvent(name: .hintUsed)); telemetry.diagnose(.saveRead)
        XCTAssertEqual(service.events.count, 1); XCTAssertEqual(service.errors.count, 1)
        telemetry.preferences(analytics: false, crashes: false)
        let count = service.events.count
        telemetry.emit(AnalyticsEvent(name: .levelComplete))
        XCTAssertEqual(service.events.count, count)
        let reloaded = Telemetry(service: MockAnalyticsService(), defaults: defaults)
        XCTAssertFalse(reloaded.analyticsEnabled); XCTAssertFalse(reloaded.crashesEnabled)
    }
    func testSchemaRejectsInvalidTypesAndReservedAutomaticNamesAreAbsent() {
        XCTAssertFalse(AnalyticsEvent(name: .adRevenue, parameters: ["value": .number(.nan)]).valid)
        XCTAssertFalse(AnalyticsEvent(name: .levelStart, parameters: ["illegal-key": .integer(1)]).valid)
        XCTAssertFalse(AnalyticsEvent(name: .levelStart, parameters: ["text": .text(String(repeating: "a", count: 101))]).valid)
        XCTAssertTrue(AnalyticsEventName.allCases.allSatisfy { $0.rawValue.count <= 40 })
        XCTAssertFalse(AnalyticsEventName.allCases.map(\.rawValue).contains("first_open"))
        XCTAssertFalse(AnalyticsEventName.allCases.map(\.rawValue).contains("session_start"))
    }
    func testAttemptTimingPauseRestartCompletionAndDuplicateCallbacks() throws {
        let (telemetry, service, _) = fixture(); telemetry.preferences(analytics: true, crashes: false)
        var time = 10.0
        let level = try LevelManager.bundled().levels[0]
        let attempt = LevelTelemetry(level: level, telemetry: telemetry, clock: { time })
        attempt.resume(); attempt.resume(); time = 20; attempt.pause(); time = 100; attempt.resume()
        attempt.hint(moves: 3); attempt.undo(moves: 3); time = 110
        attempt.complete(moves: 10); attempt.complete(moves: 10); attempt.abandon(moves: 10)
        let completions = service.events.filter { $0.name == .levelComplete }
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.parameters["completion_time"], .number(20))
        XCTAssertEqual(completions.first?.parameters["hints_used"], .integer(1))
        XCTAssertEqual(completions.first?.parameters["level_id"], .integer(1))
        XCTAssertEqual(service.events.filter { $0.name == .levelStart }.count, 1)
        attempt.restart(moves: 10); attempt.abandon(moves: 2); attempt.abandon(moves: 2)
        XCTAssertEqual(service.events.filter { $0.name == .levelRestart }.count, 1)
        XCTAssertEqual(service.events.filter { $0.name == .levelFail }.count, 1)
    }
    func testOptInMidAttemptNeverBackfillsEarlierTimeOrHints() throws {
        let (telemetry, backend, _) = fixture()
        var time = 0.0
        let attempt = LevelTelemetry(level: try LevelManager.bundled().levels[0], telemetry: telemetry, clock: { time })
        attempt.resume(); attempt.hint(moves: 1); time = 100
        telemetry.preferences(analytics: true, crashes: false)
        attempt.resume(); time = 105; attempt.complete(moves: 8)
        XCTAssertEqual(backend.events.last?.parameters["completion_time"], .number(5))
        XCTAssertEqual(backend.events.last?.parameters["hints_used"], .integer(0))
        telemetry.preferences(analytics: false, crashes: false)
        attempt.restart(moves: 8); time = 200; attempt.hint(moves: 1)
        telemetry.preferences(analytics: true, crashes: false)
        attempt.resume(); time = 203; attempt.complete(moves: 10)
        XCTAssertEqual(backend.events.last?.parameters["completion_time"], .number(3))
        XCTAssertEqual(backend.events.last?.parameters["hints_used"], .integer(0))
    }
    func testForegroundSessionsAreIdempotentAndExcludeBackground() {
        let defaults = UserDefaults(suiteName: "TelemetryTests.\(UUID())")!, service = MockAnalyticsService()
        var time = 10.0
        let telemetry = Telemetry(service: service, defaults: defaults, clock: { time })
        telemetry.preferences(analytics: true, crashes: false); telemetry.foreground(true)
        telemetry.completedAttempt(); time = 30
        telemetry.foreground(false); telemetry.foreground(false)
        XCTAssertEqual(service.events.filter { $0.name == .sessionEnd }.count, 1)
        XCTAssertEqual(service.events.last?.parameters["duration"], .number(20))
        XCTAssertEqual(service.events.last?.parameters["levels_completed"], .integer(1))
        time = 100; telemetry.foreground(true); time = 105; telemetry.foreground(false)
        XCTAssertEqual(service.events.last?.parameters["duration"], .number(5))
    }
    func testSavedPurchasesCurrencyAndRestartNeverDuplicateAndFailedSaveEmitsNothing() throws {
        let (telemetry, service, defaults) = fixture(); telemetry.preferences(analytics: true, crashes: true)
        let save = TelemetrySave()
        let progress = ProgressModel(saveService: save, enableDebugFixtures: false, telemetry: telemetry)
        save.fails = true
        XCTAssertThrowsError(try progress.fulfillPurchase(id: "verified-1", item: .coins, revoked: false))
        XCTAssertTrue(service.events.isEmpty); XCTAssertEqual(service.errors, [.saveWrite])
        save.fails = false
        try progress.fulfillPurchase(id: "verified-1", item: .coins, revoked: false)
        try progress.fulfillPurchase(id: "verified-1", item: .coins, revoked: false)
        let reload = ProgressModel(saveService: save, enableDebugFixtures: false, telemetry: Telemetry(service: service, defaults: defaults))
        try reload.fulfillPurchase(id: "verified-1", item: .coins, revoked: false)
        XCTAssertEqual(service.events.filter { $0.name == .purchaseCompleted }.count, 1)
        XCTAssertEqual(service.events.filter { $0.name == .currencyEarned }.count, 1)
        XCTAssertEqual(service.events.first?.parameters["value"], .integer(1000))
        try reload.fulfillPurchase(id: "refunded-unknown", item: .theme, revoked: true)
        XCTAssertEqual(service.events.filter { $0.name == .purchaseCompleted }.count, 1)
    }
    func testImportedRestoredEntitlementNeverReportsNewPurchase() throws {
        let (telemetry, backend, _) = fixture(); telemetry.preferences(analytics: true, crashes: false)
        let progress = ProgressModel(saveService: TelemetrySave(), enableDebugFixtures: false, telemetry: telemetry)
        try progress.fulfillPurchase(id: "restored-theme", item: .theme, revoked: false, reportPurchase: false)
        try progress.fulfillPurchase(id: "restored-theme", item: .theme, revoked: false)
        XCTAssertTrue(progress.progress.purchases.ownsTheme)
        XCTAssertFalse(backend.events.contains { $0.name == .purchaseCompleted })
        try progress.fulfillPurchase(id: "new-hints", item: .hints, revoked: false)
        XCTAssertEqual(backend.events.filter { $0.name == .purchaseCompleted }.count, 1)
    }
    func testUnavailableBackendDropsEventsAndOneShotKeysDeduplicate() {
        let (telemetry, service, _) = fixture(); telemetry.preferences(analytics: true, crashes: false)
        service.available = false
        telemetry.emit(AnalyticsEvent(name: .rewardedCompleted), once: "ticket")
        service.available = true
        telemetry.emit(AnalyticsEvent(name: .rewardedCompleted), once: "ticket")
        telemetry.emit(AnalyticsEvent(name: .rewardedCompleted), once: "ticket")
        XCTAssertEqual(service.events.count, 1)
    }
    func testSelectionUpdatesPreservePieceNodesAndResizeRedraws() throws {
        let state = try LevelManager.bundled().levels[0].state
        let scene = PuzzleScene(size: CGSize(width: 390, height: 520))
        scene.render(state: state, selected: nil)
        let node = scene.childNode(withName: "tube-0")
        let count = scene.redrawCount
        for _ in 0..<100 { scene.render(state: state, selected: 0); scene.render(state: state, selected: nil) }
        XCTAssertTrue(node === scene.childNode(withName: "tube-0"))
        XCTAssertEqual(scene.redrawCount, count)
        scene.size = CGSize(width: 320, height: 450)
        XCTAssertGreaterThan(scene.redrawCount, count)
    }
    func testRewardedTelemetryUsesEarnedCallbackAndRevenueIsNeverFabricated() async {
        let (telemetry, backend, defaults) = fixture(); telemetry.preferences(analytics: true, crashes: false)
        let service = MockAdService(); service.duplicateCallbacks = true
        let model = ProgressModel(saveService: TelemetrySave(), enableDebugFixtures: false, telemetry: telemetry)
        let ads = AdCoordinator(service: service, consent: MockAdConsentService(), defaults: defaults, telemetry: telemetry)
        await ads.start(progress: model, enabled: true); ads.location = .playing
        await ads.reward(.hint)
        XCTAssertEqual(backend.events.filter { $0.name == .rewardedStarted }.count, 1)
        XCTAssertEqual(backend.events.filter { $0.name == .rewardedCompleted }.count, 1)
        XCTAssertFalse(backend.events.contains { $0.name == .adRevenue })
        telemetry.preferences(analytics: false, crashes: false)
        let count = backend.events.count
        await ads.preload(); await ads.reward(.hint)
        XCTAssertEqual(backend.events.count, count)
    }
    func testRenderedSceneFrameCadence() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { throw XCTSkip("No renderable window scene") }
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController(); let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 520))
        controller.view = view; window.rootViewController = controller; window.makeKeyAndVisible()
        defer { view.presentScene(nil); window.isHidden = true }
        let scene = PuzzleScene(size: view.bounds.size); scene.collectsFrameMetrics = true
        let level = try LevelManager.bundled().levels[99]
        scene.render(state: level.state, selected: nil); view.presentScene(scene)
        for index in 0..<120 {
            scene.render(state: level.state, selected: index % level.state.containers.count)
            if index % 20 == 0 { scene.invalid(at: index % level.state.containers.count) }
            try await Task.sleep(for: .milliseconds(16))
        }
        let intervals = scene.frameIntervals.filter { $0 > 0 && $0 < 1 }.sorted()
        XCTAssertGreaterThan(intervals.count, 2)
        if !intervals.isEmpty {
            let report: [String: Double] = ["samples": Double(intervals.count), "mean_interval_ms": intervals.reduce(0, +) / Double(intervals.count) * 1000, "p95_interval_ms": intervals[min(intervals.count - 1, Int(Double(intervals.count) * 0.95))] * 1000]
            let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
            print("SORTSCAPE_SIMULATOR_FRAME_REPORT: " + String(decoding: data, as: UTF8.self))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); attachment.lifetime = .keepAlways; add(attachment)
        }
    }
    func testFullBoardRebuildReferencePerformance() throws {
        let state = try LevelManager.bundled().levels[99].state
        let scene = PuzzleScene(size: CGSize(width: 390, height: 520))
        scene.render(state: state, selected: nil)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for index in 0..<200 {
                scene.render(state: state, selected: index % state.containers.count)
                // Force the same full reconstruction formerly used on every selection.
                scene.didChangeSize(scene.size)
            }
        }
    }
    func testSelectionRenderingPerformance() throws {
        let state = try LevelManager.bundled().levels[99].state
        let scene = PuzzleScene(size: CGSize(width: 390, height: 520))
        scene.render(state: state, selected: nil)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for index in 0..<200 { scene.render(state: state, selected: index % state.containers.count) }
        }
    }
}
