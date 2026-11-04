import Foundation
import XCTest
import PuzzleCore
@testable import SortScape

@MainActor
final class AdCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var clock = Date(timeIntervalSince1970: 2_000_000_000)
    override func setUp() { super.setUp(); suite = "AdTests.\(UUID())"; defaults = UserDefaults(suiteName: suite)! }
    override func tearDown() { defaults.removePersistentDomain(forName: suite); defaults = nil; super.tearDown() }
    private func setup(service: MockAdService, consent: MockAdConsentService = MockAdConsentService(), model: ProgressModel? = nil) async -> (AdCoordinator, ProgressModel) {
        let progress = model ?? ProgressModel(saveService: ProgressStore(url: FileManager.default.temporaryDirectory.appending(path: "AdTests/\(suite!)/save.json")), enableDebugFixtures: false)
        let ads = AdCoordinator(service: service, consent: consent, defaults: defaults, now: { self.clock })
        await ads.start(progress: progress, enabled: true)
        ads.location = .playing
        return (ads, progress)
    }
    func testEarnedRewardDuplicateCallbacksAndRestartNeverDuplicateTokens() async throws {
        let service = MockAdService(); service.duplicateCallbacks = true
        let (ads, progress) = await setup(service: service)
        await ads.reward(.hint)
        XCTAssertEqual(progress.progress.availableHints, 1)
        XCTAssertEqual(progress.progress.adRewards.claims.count, 1)
        XCTAssertEqual(ads.analytics.snapshot.counters["reward_granted"], 1)
        XCTAssertEqual(ads.analytics.snapshot.counters["rewarded_completed"], 1)
        let saved = progress.progress
        ads.retryPendingRewards(); XCTAssertEqual(progress.progress, saved)
    }
    func testLoadFailureDismissalAndPresentationFailureGrantNothing() async {
        let service = MockAdService(); service.loadSucceeds = false
        let (ads, progress) = await setup(service: service)
        await ads.reward(.hint)
        XCTAssertEqual(progress.progress.availableHints, 0); XCTAssertEqual(progress.progress.coins, 0)
        service.loadSucceeds = true; await ads.preload(); service.earnsReward = false
        await ads.reward(.hint)
        XCTAssertEqual(progress.progress.availableHints, 0)
        clock = clock.addingTimeInterval(31); service.presentationSucceeds = false
        await ads.preload(); await ads.reward(.undo)
        XCTAssertEqual(progress.progress.adRewards.undos, 0)
        XCTAssertFalse(ads.busy)
    }
    func testConsentDeniedErrorWithdrawnAndDisabledNeverInitializeOrLoad() async {
        let service = MockAdService(), consent = MockAdConsentService(); consent.canRequestAds = false
        let (ads, _) = await setup(service: service, consent: consent)
        XCTAssertEqual(service.initializeCount, 0); XCTAssertFalse(ads.rewardedAvailable)
        consent.canRequestAds = true; consent.fails = true
        await ads.enableTestAds(); XCTAssertEqual(service.initializeCount, 0)
        consent.fails = false; await ads.enableTestAds(); XCTAssertEqual(service.initializeCount, 1)
        consent.canRequestAds = false; await ads.privacyOptions()
        XCTAssertFalse(ads.consentAllowed); XCTAssertFalse(service.rewardedReady)
        consent.canRequestAds = true; await ads.enableTestAds(); ads.disable()
        XCTAssertFalse(ads.enabled); XCTAssertFalse(service.rewardedReady)
        await ads.reward(.hint); XCTAssertEqual(service.presentations, 0)
        let restarted = AdCoordinator(service: MockAdService(), consent: MockAdConsentService(), defaults: defaults, now: { self.clock })
        let progress = ProgressModel(saveService: ProgressStore(url: FileManager.default.temporaryDirectory.appending(path: "AdTests/\(suite!)/restart.json")), enableDebugFixtures: false)
        await restarted.start(progress: progress, enabled: true)
        XCTAssertFalse(restarted.enabled, "Device opt-out survives launch")
    }
    func testOptOutWhileConsentIsInFlightNeverInitializesSDK() async {
        let service = MockAdService(), consent = MockAdConsentService(); consent.holdUpdate = true
        let model = ProgressModel(saveService: ProgressStore(url: FileManager.default.temporaryDirectory.appending(path: "AdTests/\(suite!)/late.json")), enableDebugFixtures: false)
        let ads = AdCoordinator(service: service, consent: consent, defaults: defaults, now: { self.clock })
        let start = Task { await ads.start(progress: model, enabled: true) }
        for _ in 0..<100 where !ads.loading { await Task.yield() }
        ads.disable(); consent.completeUpdate(); await start.value
        XCTAssertFalse(ads.enabled); XCTAssertFalse(ads.consentAllowed)
        XCTAssertEqual(service.initializeCount, 0); XCTAssertFalse(service.rewardedReady)
        XCTAssertEqual(consent.cancellationCount, 1)
    }
    func testConcurrentPresentationAndBackgroundCannotGrantAdditionalRewards() async throws {
        let service = MockAdService(); service.holdPresentation = true
        let (ads, progress) = await setup(service: service)
        let first = Task { await ads.reward(.hint) }
        for _ in 0..<100 where !ads.busy { await Task.yield() }
        XCTAssertTrue(ads.busy)
        await ads.reward(.undo)
        XCTAssertEqual(service.presentations, 1); XCTAssertEqual(progress.progress.availableHints, 1)
        ads.foreground(false); service.dismiss(); await first.value
        XCTAssertFalse(ads.busy)
        await ads.reward(.hint); XCTAssertEqual(service.presentations, 1)
    }
    func testInterstitialOnlyEveryTenthLevelAfterFirstSessionAndNeverForRemoveAds() async throws {
        let model = ProgressModel(saveService: ProgressStore(url: FileManager.default.temporaryDirectory.appending(path: "AdTests/\(suite!)/save.json")), enableDebugFixtures: false)
        for level in try LevelManager.bundled().levels.prefix(10) {
            guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { return XCTFail("Missing solution") }
            var board = PuzzleSession(state: level.state)
            for move in moves { board.move(from: move.source, to: move.destination) }
            _ = model.complete(level: level, session: board)
        }
        let firstService = MockAdService()
        let (first, _) = await setup(service: firstService, model: model)
        clock = clock.addingTimeInterval(200); first.location = .completed(10)
        await first.betweenLevels(completedLevel: 10); XCTAssertEqual(firstService.presentations, 0)
        let service = MockAdService()
        let (second, _) = await setup(service: service, model: model)
        clock = clock.addingTimeInterval(180)
        await second.betweenLevels(completedLevel: 10); XCTAssertEqual(service.presentations, 0)
        second.location = .completed(9)
        await second.betweenLevels(completedLevel: 9)
        XCTAssertEqual(service.presentations, 0)
        second.location = .completed(10); await second.betweenLevels(completedLevel: 10)
        XCTAssertEqual(service.presentations, 1)
        await second.preload(); await second.betweenLevels(completedLevel: 10); XCTAssertEqual(service.presentations, 1)
        clock = clock.addingTimeInterval(180)
        try model.fulfillPurchase(id: "Xcode.ads", item: .removeAds, revoked: false)
        await second.betweenLevels(completedLevel: 10); XCTAssertEqual(service.presentations, 1)
        // Optional rewarded ads still require an explicit request from an ad-free player.
        second.location = .playing; await second.reward(.hint)
        XCTAssertEqual(model.progress.availableHints, 1)
    }
    func testOfflineGameRemainsPlayableWithNoAdServiceAvailability() async throws {
        let service = MockAdService(); service.loadSucceeds = false
        let (ads, progress) = await setup(service: service)
        let game = GameModel(level: try LevelManager.bundled().levels[0]); game.reduceMotion = true
        game.select(0); game.select(2)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(game.session.moveCount, 1)
        game.undo(); XCTAssertEqual(game.session.moveCount, 0)
        await ads.reward(.hint); XCTAssertEqual(progress.progress.coins, 0)
        game.leave()
    }
    func testLocalAnalyticsContainNoIDsAndValidateRevenue() async throws {
        let analytics = AdAnalytics(defaults: defaults)
        analytics.session(at: clock); analytics.session(at: clock.addingTimeInterval(86400))
        analytics.record(.impression(.rewarded), at: clock)
        analytics.record(.revenue(.rewarded, 0.125, "USD"), at: clock)
        analytics.record(.revenue(.rewarded, .nan, "USD"), at: clock)
        analytics.record(.revenue(.rewarded, 1, "user-id"), at: clock)
        XCTAssertEqual(analytics.snapshot.revenueMicros["USD"], 125_000)
        XCTAssertEqual(analytics.snapshot.revenueMicros.count, 1)
        XCTAssertEqual(analytics.snapshot.returnedDays.count, 2)
        let data = try JSONEncoder().encode(analytics.snapshot), text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("user-id")); XCTAssertFalse(text.contains("ca-app"))
    }
    func testLinkedSDKUsesSampleAppAndDelayedMeasurementWithoutATTPrompt() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String, GoogleAdMobService.sampleAppID)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "GADDelayAppMeasurementInit") as? Bool, true)
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription"))
    }
}
