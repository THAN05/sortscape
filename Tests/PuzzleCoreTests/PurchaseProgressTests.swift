import Foundation
import XCTest
@testable import PuzzleCore

final class PurchaseProgressTests: XCTestCase {
    func testConsumablesAreAtomicIdempotentAndPersistAfterRestart() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "progress.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = ProgressStore(url: url)
        var progress = PlayerProgress()
        try progress.fulfillPurchase(id: "Xcode.100", item: .coins, revoked: false)
        try progress.fulfillPurchase(id: "Xcode.101", item: .hints, revoked: false)
        XCTAssertEqual(progress.coins, 1000); XCTAssertEqual(progress.purchases.hints, 10)
        XCTAssertTrue(progress.consumeHint())
        try store.save(progress)
        progress = try store.load()
        try progress.fulfillPurchase(id: "Xcode.100", item: .coins, revoked: false)
        try progress.fulfillPurchase(id: "Xcode.101", item: .hints, revoked: false)
        XCTAssertEqual(progress.coins, 1000); XCTAssertEqual(progress.purchases.hints, 9)
        XCTAssertEqual(progress.economy.lifetimeCoinsEarned, 1000)
        XCTAssertThrowsError(try progress.fulfillPurchase(id: "Xcode.100", item: .starter, revoked: false))
        XCTAssertEqual(progress.coins, 1000)
    }
    func testStarterRewardsNeverRepeatOnRestoreRefundOrRepurchase() throws {
        var progress = PlayerProgress()
        try progress.fulfillPurchase(id: "Xcode.1", item: .starter, revoked: false)
        try progress.fulfillPurchase(id: "Xcode.1", item: .starter, revoked: false)
        XCTAssertEqual(progress.coins, 1500); XCTAssertEqual(progress.purchases.hints, 20)
        XCTAssertTrue(progress.purchases.removesAds)
        try progress.fulfillPurchase(id: "Xcode.1", item: .starter, revoked: true)
        XCTAssertFalse(progress.purchases.removesAds)
        try progress.fulfillPurchase(id: "Xcode.1", item: .starter, revoked: false)
        XCTAssertFalse(progress.purchases.removesAds)
        try progress.fulfillPurchase(id: "Xcode.2", item: .starter, revoked: false)
        XCTAssertTrue(progress.purchases.removesAds)
        XCTAssertEqual(progress.coins, 1500); XCTAssertEqual(progress.purchases.hints, 20)
    }
    func testReconciliationRemovesRevokedThemeAndHintsNeverGoNegative() throws {
        var progress = PlayerProgress()
        XCTAssertFalse(progress.consumeHint()); XCTAssertFalse(progress.selectPremiumTheme(true))
        try progress.fulfillPurchase(id: "Xcode.1", item: .theme, revoked: false)
        XCTAssertTrue(progress.selectPremiumTheme(true))
        try progress.reconcilePurchases([])
        XCTAssertFalse(progress.purchases.ownsTheme); XCTAssertFalse(progress.purchases.premiumThemeSelected)
        XCTAssertThrowsError(try progress.reconcilePurchases([.coins]))
        try progress.fulfillPurchase(id: "Xcode.2", item: .hints, revoked: true)
        try progress.fulfillPurchase(id: "Xcode.2", item: .hints, revoked: false)
        XCTAssertEqual(progress.purchases.hints, 0)
        try progress.fulfillPurchase(id: "Xcode.3", item: .hints, revoked: false)
        for _ in 0..<10 { XCTAssertTrue(progress.consumeHint()) }
        XCTAssertFalse(progress.consumeHint())
        XCTAssertTrue(progress.isValid)
    }
    func testVersionThreeMigrationPreservesWalletAndRequiresV4Journal() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "save.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let level = try LevelManager.bundled().levels[0]
        var historical = PlayerProgress(), board = PuzzleSession(state: level.state)
        guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { return XCTFail("Missing level solution") }
        for move in moves { board.move(from: move.source, to: move.destination) }
        historical.complete(level: level, session: board)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(historical)) as? [String: Any])
        var economy = try XCTUnwrap(object["economy"] as? [String: Any])
        var transactions = try XCTUnwrap(economy["transactions"] as? [String: Any])
        transactions["restoration.pathways"] = ["id": "restoration.pathways", "kind": "spend", "coins": -20, "stars": 0]
        economy["transactions"] = transactions
        object["economy"] = economy
        object["island"] = ["restored": ["pathways"]]
        object.removeValue(forKey: "purchaseState")
        let old = try JSONSerialization.data(withJSONObject: ["version": 3, "progress": object])
        try old.write(to: url)
        let store = ProgressStore(url: url), progress = try store.load()
        XCTAssertEqual(progress.coins, 15); XCTAssertEqual(progress.island.completionPercentage, 10); XCTAssertEqual(progress.starBalance, 3); XCTAssertTrue(progress.hasPurchaseJournal)
        try store.save(progress)
        XCTAssertEqual(try Data(contentsOf: url.appendingPathExtension("v3.backup")), old)
        XCTAssertEqual(try store.load(), progress)
        let corrupt = try JSONSerialization.data(withJSONObject: ["version": 4, "progress": object])
        try corrupt.write(to: url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }
}
