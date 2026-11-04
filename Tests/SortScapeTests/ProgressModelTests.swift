import Foundation
import XCTest
import PuzzleCore
@testable import SortScape

private final class MemorySaveService: PlayerSaveService, @unchecked Sendable {
    private let lock = NSLock()
    private var value: PlayerProgress
    private var failing = false
    init(_ progress: PlayerProgress = PlayerProgress()) { value = progress }
    func setFailure(_ value: Bool) { lock.lock(); defer { lock.unlock() }; failing = value }
    func load(campaign: LevelManager?) throws -> PlayerProgress { lock.lock(); defer { lock.unlock() }; return value }
    func save(_ progress: PlayerProgress) throws {
        lock.lock(); defer { lock.unlock() }
        if failing { throw CocoaError(.fileWriteUnknown) }
        value = progress
    }
}

@MainActor
final class ProgressModelTests: XCTestCase {
    private func solved(_ level: Level) throws -> PuzzleSession {
        guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { throw LevelError.validationFailed(level.id) }
        var session = PuzzleSession(state: level.state)
        for move in moves { session.move(from: move.source, to: move.destination) }
        return session
    }
    func testFailedRewardSaveDoesNotPublishAndCanRetryExactlyOnce() throws {
        let service = MemorySaveService(), campaign = try LevelManager.bundled()
        let model = ProgressModel(saveService: service, campaign: campaign, enableDebugFixtures: false)
        let level = campaign.levels[0], session = try solved(level)
        service.setFailure(true)
        XCTAssertEqual(model.complete(level: level, session: session).coinsEarned, 0)
        XCTAssertEqual(model.progress.coins, 0); XCTAssertEqual(model.progress.starBalance, 0)
        XCTAssertNotNil(model.error)
        service.setFailure(false)
        XCTAssertEqual(model.complete(level: level, session: session).coinsEarned, 35)
        XCTAssertEqual(model.complete(level: level, session: session).coinsEarned, 0)
        XCTAssertEqual(model.progress.coins, 35); XCTAssertNil(model.error)
    }
    func testFailedConstructionSaveRollsBackBothWalletAndIsland() throws {
        let service = MemorySaveService(), campaign = try LevelManager.bundled()
        let model = ProgressModel(saveService: service, campaign: campaign, enableDebugFixtures: false)
        _ = model.complete(level: campaign.levels[0], session: try solved(campaign.levels[0]))
        try model.fulfillPurchase(id: "test.coins", item: .coins, revoked: false)
        service.setFailure(true)
        XCTAssertEqual(model.restore(.pathways), .invalidTransaction)
        XCTAssertEqual(model.progress.coins, 1035); XCTAssertTrue(model.progress.island.restored.isEmpty)
        XCTAssertEqual(model.progress.economy.lifetimeCoinsSpent, 0)
        service.setFailure(false)
        XCTAssertEqual(model.restore(.pathways), .restored(milestoneCoins: 0))
        XCTAssertEqual(model.progress.coins, 835)
        XCTAssertEqual(model.restore(.pathways), .alreadyRestored)
        XCTAssertEqual(model.progress.economy.lifetimeCoinsSpent, 200)
    }
    func testFreshInjectedModelRetainsWalletStarsAndRestoration() throws {
        let service = MemorySaveService(), campaign = try LevelManager.bundled()
        let first = ProgressModel(saveService: service, campaign: campaign, enableDebugFixtures: false)
        _ = first.complete(level: campaign.levels[0], session: try solved(campaign.levels[0]))
        try first.fulfillPurchase(id: "test.coins", item: .coins, revoked: false)
        _ = first.restore(.pathways)
        let restarted = ProgressModel(saveService: service, campaign: campaign, enableDebugFixtures: false)
        XCTAssertEqual(restarted.progress.coins, 835); XCTAssertEqual(restarted.progress.starBalance, 3)
        XCTAssertEqual(restarted.progress.island.completionPercentage, 10)
        XCTAssertTrue(restarted.progress.isUnlocked(2))
        XCTAssertEqual(restarted.restore(.pathways), .alreadyRestored)
    }
    func testPurchaseAndHintSaveFailuresNeverPublishPartialFulfillment() throws {
        let service = MemorySaveService()
        let model = ProgressModel(saveService: service, enableDebugFixtures: false)
        service.setFailure(true)
        XCTAssertThrowsError(try model.fulfillPurchase(id: "Xcode.1", item: .starter, revoked: false))
        XCTAssertEqual(model.progress.coins, 0); XCTAssertEqual(model.progress.purchases.hints, 0)
        XCTAssertTrue(model.progress.purchases.fulfilled.isEmpty)
        service.setFailure(false)
        try model.fulfillPurchase(id: "Xcode.1", item: .starter, revoked: false)
        try model.fulfillPurchase(id: "Xcode.1", item: .starter, revoked: false)
        XCTAssertEqual(model.progress.coins, 1500); XCTAssertEqual(model.progress.purchases.hints, 20)
        service.setFailure(true)
        XCTAssertFalse(model.useHint(in: 1, spendingToken: true)); XCTAssertEqual(model.progress.purchases.hints, 20)
        service.setFailure(false)
        XCTAssertTrue(model.useHint(in: 1, spendingToken: true)); XCTAssertEqual(model.progress.purchases.hints, 19)
        let restart = ProgressModel(saveService: service, enableDebugFixtures: false)
        XCTAssertEqual(restart.progress, model.progress)
        XCTAssertTrue(restart.progress.hasUsedHint(in: 1))
        XCTAssertFalse(restart.useHint(in: 1))
        XCTAssertFalse(restart.useHint(in: 1, spendingToken: true))
        XCTAssertEqual(restart.progress.availableHints, 19)
    }

    func testEarnedAdRewardSaveFailureRetriesWithoutDuplicateDelivery() throws {
        let service = MemorySaveService()
        let injected = ProgressModel(saveService: service, enableDebugFixtures: false)
        let id = UUID().uuidString
        service.setFailure(true)
        XCTAssertThrowsError(try injected.claimAdReward(id: id, reward: .hint))
        XCTAssertEqual(injected.progress.availableHints, 0)
        XCTAssertTrue(injected.progress.adRewards.claims.isEmpty)
        service.setFailure(false)
        XCTAssertTrue(try injected.claimAdReward(id: id, reward: .hint))
        XCTAssertFalse(try injected.claimAdReward(id: id, reward: .hint))
        let restarted = ProgressModel(saveService: service, enableDebugFixtures: false)
        XCTAssertEqual(restarted.progress.availableHints, 1)
        XCTAssertFalse(try restarted.claimAdReward(id: id, reward: .hint))
    }

    func testCoordinatorRetainsEarnedRewardUntilSaveRetrySucceeds() async {
        let service = MemorySaveService(), model = ProgressModel(saveService: service, enableDebugFixtures: false)
        let name = "PendingAd.\(UUID())", mock = MockAdService()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let ads = AdCoordinator(service: mock, consent: MockAdConsentService(), defaults: defaults)
        await ads.start(progress: model, enabled: true); ads.location = .playing
        service.setFailure(true); await ads.reward(.hint)
        XCTAssertTrue(ads.hasPendingReward); XCTAssertEqual(model.progress.availableHints, 0)
        service.setFailure(false); ads.retryPendingRewards()
        XCTAssertFalse(ads.hasPendingReward); XCTAssertEqual(model.progress.availableHints, 1)
        ads.retryPendingRewards(); XCTAssertEqual(model.progress.adRewards.claims.count, 1)
        XCTAssertEqual(ads.analytics.snapshot.counters["reward_granted"], 1)
    }

}
