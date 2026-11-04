import Foundation
import XCTest
@testable import PuzzleCore

final class EconomyTests: XCTestCase {
    private func solved(_ level: Level) throws -> PuzzleSession {
        guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { throw LevelError.validationFailed(level.id) }
        var session = PuzzleSession(state: level.state)
        for move in moves { session.move(from: move.source, to: move.destination) }
        return session
    }
    private func completed(_ count: Int) throws -> PlayerProgress {
        var progress = PlayerProgress()
        for level in try LevelManager.bundled().levels.prefix(count) { progress.complete(level: level, session: try solved(level)) }
        return progress
    }
    func testCurrencyAwardsSpendingAndLifetimeTotalsAreSeparate() {
        var economy = EconomyManager()
        XCTAssertEqual(economy.award(id: "reward", coins: 100, stars: 3), .applied)
        XCTAssertEqual(economy.spend(id: "coin-purchase", coins: 30), .applied)
        XCTAssertEqual(economy.spend(id: "star-purchase", coins: 0, stars: 1), .applied)
        XCTAssertEqual(economy.coins, 70); XCTAssertEqual(economy.stars, 2)
        XCTAssertEqual(economy.lifetimeCoinsEarned, 100); XCTAssertEqual(economy.lifetimeCoinsSpent, 30)
        XCTAssertEqual(economy.lifetimeStarsEarned, 3); XCTAssertEqual(economy.lifetimeStarsSpent, 1)
    }
    func testTransactionsAreIdempotentAndConflictsCannotChangeBalances() {
        var economy = EconomyManager()
        economy.award(id: "clear-1", coins: 35, stars: 3)
        XCTAssertEqual(economy.award(id: "clear-1", coins: 35, stars: 3), .duplicate)
        XCTAssertEqual(economy.award(id: "clear-1", coins: 99), .conflict)
        economy.spend(id: "build-1", coins: 20)
        XCTAssertEqual(economy.spend(id: "build-1", coins: 20), .duplicate)
        XCTAssertEqual(economy.coins, 15); XCTAssertEqual(economy.stars, 3)
    }
    func testInsufficientInvalidAndOverflowAmountsNeverMutateLedger() {
        var economy = EconomyManager()
        economy.award(id: "start", coins: 10, stars: 1)
        let before = economy
        XCTAssertEqual(economy.spend(id: "too-expensive", coins: 11), .insufficientFunds)
        XCTAssertEqual(economy.spend(id: "too-many-stars", coins: 0, stars: 2), .insufficientFunds)
        XCTAssertEqual(economy.award(id: "negative", coins: -1), .invalidTransaction)
        XCTAssertEqual(economy.award(id: "overflow", coins: Int.max), .invalidTransaction)
        XCTAssertEqual(economy.spend(id: "overflow", coins: Int.min), .invalidTransaction)
        XCTAssertEqual(economy.spend(id: "zero", coins: 0), .invalidTransaction)
        XCTAssertEqual(economy.award(id: "", coins: 1), .invalidTransaction)
        XCTAssertEqual(economy, before)
    }
    func testReceiptTracksCoinsStarsBonusesAndNoReplayFarm() throws {
        let level = try LevelManager.bundled().levels[0]
        var progress = PlayerProgress()
        let receipt = progress.completeWithReceipt(level: level, session: try solved(level))
        XCTAssertEqual(receipt.baseCoins, 25); XCTAssertEqual(receipt.efficiencyCoins, 10)
        XCTAssertEqual(receipt.starsEarned, 3); XCTAssertEqual(receipt.rating, 3)
        XCTAssertEqual(receipt.coinsEarned, 35)
        XCTAssertEqual(progress.completeWithReceipt(level: level, session: try solved(level)).coinsEarned, 0)
        XCTAssertEqual(progress.starBalance, 3)
        XCTAssertEqual(progress.economy.lifetimeCoinsEarned, 35)
    }
    func testRestorationRequirementsInsufficientCoinsAndDuplicateBuild() throws {
        var progress = PlayerProgress()
        let path = RestorationItem.all[0]
        XCTAssertEqual(progress.restorationStatus(path), .locked)
        XCTAssertEqual(progress.restore(.pathways), .locked)
        progress = try completed(1)
        try progress.fulfillPurchase(id: "test.coins", item: .coins, revoked: false)
        XCTAssertEqual(progress.restorationStatus(path), .available)
        XCTAssertEqual(progress.restore(.pathways), .restored(milestoneCoins: 0))
        XCTAssertEqual(progress.coins, 835); XCTAssertEqual(progress.starBalance, 3)
        XCTAssertEqual(progress.island.completionPercentage, 10)
        XCTAssertEqual(progress.restore(.pathways), .alreadyRestored)
        XCTAssertEqual(progress.economy.lifetimeCoinsSpent, 200)
        XCTAssertEqual(progress.restore(.trees), .locked)
        let second = try LevelManager.bundled().levels[1]
        progress.complete(level: second, session: try solved(second))
        XCTAssertEqual(progress.restore(.trees), .restored(milestoneCoins: 20))
        XCTAssertEqual(progress.coins, 590)
        XCTAssertEqual(progress.restore(.trees), .alreadyRestored)
        XCTAssertEqual(progress.restore(.cottage), .locked)
        // The garden requires its predecessor and a third completed world.
        let third = try LevelManager.bundled().levels[2]
        progress.complete(level: third, session: try solved(third))
        XCTAssertEqual(progress.restore(.flowerGarden), .restored(milestoneCoins: 0))
        XCTAssertGreaterThanOrEqual(progress.coins, 0)
    }
    func testPerfectCampaignNeedsTwentyRewardedAdsToCompleteIsland() throws {
        var progress = try completed(100)
        XCTAssertEqual(RestorationItem.all.count, 10)
        XCTAssertEqual(RestorationItem.all.last?.requiredLevels, 100)
        let cost = RestorationItem.all.reduce(0) { $0 + $1.cost }
        XCTAssertEqual(cost, 31_550)
        for item in RestorationItem.all.dropLast() {
            guard case .restored = progress.restore(item.id) else { return XCTFail("Cannot restore \(item.name)") }
            let before = progress
            XCTAssertEqual(progress.restore(item.id), .alreadyRestored)
            XCTAssertEqual(progress, before)
        }
        XCTAssertEqual(progress.restore(.lighthouse), .insufficientCoins(needed: 500))
        for level in 1...19 {
            XCTAssertTrue(try progress.claimAdReward(id: UUID().uuidString, reward: .levelCoins(level)))
        }
        XCTAssertEqual(progress.restore(.lighthouse), .insufficientCoins(needed: 25))
        XCTAssertTrue(try progress.claimAdReward(id: UUID().uuidString, reward: .levelCoins(20)))
        XCTAssertEqual(progress.restore(.lighthouse), .restored(milestoneCoins: 75))
        XCTAssertEqual(progress.island.completionPercentage, 100)
        XCTAssertNil(progress.nextRestorationObjective)
        XCTAssertEqual(progress.economy.lifetimeCoinsSpent, cost)
        XCTAssertEqual(progress.coins, 75)
        XCTAssertEqual(progress.starBalance, 300)
    }
    func testV2MigrationPreservesBalancesAndPreventsRetroactiveBonuses() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(completed(5))) as! [String: Any]
        object.removeValue(forKey: "economy"); object.removeValue(forKey: "island")
        let original = try JSONSerialization.data(withJSONObject: ["version": 2, "progress": object])
        let store = ProgressStore(url: directory.appendingPathComponent("progress.json"))
        try original.write(to: store.url)
        var restored = try store.load()
        XCTAssertEqual(restored.coins, 125); XCTAssertEqual(restored.starBalance, 15)
        XCTAssertEqual(restored.economy.lifetimeCoinsSpent, 0)
        let first = try LevelManager.bundled().levels[0]
        XCTAssertEqual(restored.complete(level: first, session: try solved(first)), 0)
        XCTAssertEqual(restored.restore(.pathways), .insufficientCoins(needed: 75))
        try store.save(restored)
        XCTAssertEqual(try Data(contentsOf: store.url.appendingPathExtension("v2.backup")), original)
        XCTAssertEqual(try store.load(), restored)
    }
    func testLegacyLighthousePriceAndUnlockStillLoad() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try completed(30)
        var profile = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var economy = try XCTUnwrap(profile["economy"] as? [String: Any])
        var transactions = try XCTUnwrap(economy["transactions"] as? [String: Any])
        transactions.removeValue(forKey: "milestone.restoration-funding.8")
        transactions.removeValue(forKey: "milestone.restoration-funding.25")
        let purchases = ["pathways": 20, "bridge": 90, "lighthouse": 200]
        for (decoration, cost) in purchases {
            let id = "restoration.\(decoration)"
            transactions[id] = ["id": id, "kind": "spend", "coins": -cost, "stars": 0]
        }
        economy["transactions"] = transactions
        profile["economy"] = economy
        profile["island"] = ["restored": Array(purchases.keys)]
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        try JSONSerialization.data(withJSONObject: ["version": 5, "progress": profile]).write(to: store.url)

        var restored = try store.load()
        XCTAssertTrue(restored.island.restored.contains(.lighthouse))
        XCTAssertEqual(restored.coins, original.coins - 5_200 - 310)
        XCTAssertEqual(restored.restore(.lighthouse), .alreadyRestored)
        XCTAssertEqual(restored.claimRestorationFunding(), 5_200)
        XCTAssertEqual(restored.coins, original.coins - 310)
        XCTAssertEqual(restored.claimRestorationFunding(), 0)
        try store.save(restored)
        XCTAssertEqual(try store.load(), restored)
    }

    func testInsufficientRestorationFundsNeverSpendOrPlaceDecoration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(completed(8))) as! [String: Any]
        object.removeValue(forKey: "economy"); object.removeValue(forKey: "island")
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        try JSONSerialization.data(withJSONObject: ["version": 2, "progress": object]).write(to: store.url)
        var progress = try store.load()
        XCTAssertEqual(progress.restore(.pathways), .restored(milestoneCoins: 0))
        XCTAssertEqual(progress.coins, 0)
        let bridge = RestorationItem.all.first { $0.id == .bridge }!
        XCTAssertEqual(progress.restorationStatus(bridge), .insufficientCoins)
        let before = progress
        XCTAssertEqual(progress.restore(.bridge), .insufficientCoins(needed: 1600))
        XCTAssertEqual(progress, before)
    }
    func testV3SaveRestartsRetainSpentBalancesIslandAndMilestoneIDs() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("save.json")
        var progress = try completed(2)
        try progress.fulfillPurchase(id: "test.coins", item: .coins, revoked: false)
        _ = progress.restore(.pathways); _ = progress.restore(.trees)
        try ProgressStore(url: url).save(progress)
        var restored = try ProgressStore(url: url).load()
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.island.completionPercentage, 20)
        XCTAssertEqual(restored.restore(.trees), .alreadyRestored)
        XCTAssertEqual(restored.coins, 590)
        let third = try LevelManager.bundled().levels[2]
        restored.complete(level: third, session: try solved(third))
        XCTAssertEqual(restored.coins, 625)
    }
    func testCorruptV3AndFutureSavesAreRejectedWithoutOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(PlayerProgress())) as! [String: Any]
        object["economy"] = ["transactions": ["bad": ["id": "bad", "kind": "award", "coins": Int.min, "stars": 0]]]
        for version in [3, 99] {
            let data = try JSONSerialization.data(withJSONObject: ["version": version, "progress": object]); try data.write(to: store.url)
            XCTAssertThrowsError(try store.load()); XCTAssertEqual(try Data(contentsOf: store.url), data)
        }
        object.removeValue(forKey: "economy")
        let data = try JSONSerialization.data(withJSONObject: ["version": 3, "progress": object]); try data.write(to: store.url)
        XCTAssertThrowsError(try store.load())
    }
}
