import Foundation
import XCTest
import StoreKit
import StoreKitTest
import PuzzleCore
@testable import SortScape

@MainActor
final class StoreKitPurchaseTests: XCTestCase {
    private var session: SKTestSession!
    private var directory: URL!
    private var catalog: StoreCatalog!
    private var progress: ProgressModel!
    private var purchases: StoreKitPurchaseManager!
    override func setUp() async throws {
        try await super.setUp()
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SortScape", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        catalog = try StoreCatalog.bundled()
        progress = ProgressModel(saveService: ProgressStore(url: directory.appending(path: "save.json")), enableDebugFixtures: false)
        purchases = StoreKitPurchaseManager(catalog: catalog, progress: progress, permitsPurchases: true)
        _ = try await purchases.loadProducts()
    }
    override func tearDown() async throws {
        await purchases?.stop()
        session?.clearTransactions(); session?.resetToDefaultState()
        if let directory { try? FileManager.default.removeItem(at: directory) }
        purchases = nil; progress = nil; session = nil
        try await super.tearDown()
    }
    private func buy(_ item: StoreItem) async -> PurchaseOutcome { await purchases.purchase(item) }
    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Expected StoreKit update did not arrive")
    }
    func testRealStoreKitProductsAndSuccessfulConsumablesPersistExactlyOnce() async throws {
        let loaded = try await purchases.loadProducts()
        XCTAssertEqual(loaded.count, 5)
        XCTAssertTrue(loaded.allSatisfy { !$0.displayPrice.isEmpty })
        let outcome = await buy(.coins); XCTAssertEqual(outcome, .success)
        let hints = await buy(.hints); XCTAssertEqual(hints, .success)
        XCTAssertEqual(progress.progress.coins, 1000); XCTAssertEqual(progress.progress.purchases.hints, 10)
        await purchases.recoverUnfinished(); await purchases.recoverUnfinished()
        let reloaded = ProgressModel(saveService: ProgressStore(url: directory.appending(path: "save.json")), enableDebugFixtures: false)
        let newManager = StoreKitPurchaseManager(catalog: catalog, progress: reloaded, permitsPurchases: true)
        await newManager.start(); await newManager.stop()
        XCTAssertEqual(reloaded.progress.coins, 1000); XCTAssertEqual(reloaded.progress.purchases.hints, 10)
        XCTAssertEqual(reloaded.progress.purchases.fulfilled.count, 2)
    }
    func testUserCancellationAndFailureGrantNothing() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        // Xcode 27.1 translates simulated .userCancelled errors to StoreKitError.unknown.
        // Exercise the actual PurchaseResult cancellation branch separately.
        let cancelled = await purchases.handle(.userCancelled); XCTAssertEqual(cancelled, .cancelled)
        let simulated = await buy(.coins)
        guard case .failed = simulated else { return XCTFail("Expected Xcode's wrapped cancellation error") }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        let failed = await buy(.coins)
        guard case .failed = failed else { return XCTFail("Expected purchase error, got \(failed)") }
        XCTAssertEqual(progress.progress.coins, 0); XCTAssertTrue(progress.progress.purchases.fulfilled.isEmpty)
    }
    func testPendingApprovalDeliversViaUpdatesOnlyAfterApproval() async throws {
        session.askToBuyEnabled = true
        await purchases.start()
        let pending = await buy(.coins); XCTAssertEqual(pending, .pending)
        XCTAssertEqual(progress.progress.coins, 0)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await waitUntil { self.progress.progress.coins == 1000 }
        await purchases.recoverUnfinished()
        XCTAssertEqual(progress.progress.coins, 1000)
    }
    func testInterruptedDeliveryRetriesAfterFailedSaveAndRestart() async throws {
        // A verified, unfinished transaction exists before the app can persist it.
        _ = try await session.buyProduct(identifier: catalog.identifiers[.coins]!)
        let blocking = directory.appending(path: "blocked")
        try Data([1]).write(to: blocking)
        let broken = ProgressModel(saveService: ProgressStore(url: blocking.appending(path: "save.json")), enableDebugFixtures: false)
        let brokenManager = StoreKitPurchaseManager(catalog: catalog, progress: broken, permitsPurchases: true)
        let delivered = await brokenManager.recoverUnfinished()
        XCTAssertFalse(delivered); XCTAssertEqual(broken.progress.coins, 0)
        await purchases.start()
        // The simulator may publish a recovered transaction through the listener
        // just after the initial unfinished snapshot has been consumed.
        try await waitUntil { self.progress.progress.coins == 1000 }
        await purchases.recoverUnfinished()
        XCTAssertEqual(progress.progress.coins, 1000)
    }
    func testRestoreReconcilesNonConsumablesAndStarterRewardsDoNotRepeat() async throws {
        let starter = await buy(.starter); XCTAssertEqual(starter, .success)
        let theme = await buy(.theme); XCTAssertEqual(theme, .success)
        XCTAssertEqual(progress.progress.coins, 1500); XCTAssertEqual(progress.progress.purchases.hints, 20)
        try progress.reconcilePurchases([])
        XCTAssertFalse(progress.progress.purchases.ownsTheme)
        let restored = await purchases.restore(); XCTAssertEqual(restored, .success)
        XCTAssertTrue(progress.progress.purchases.removesAds); XCTAssertTrue(progress.progress.purchases.ownsTheme)
        let again = await purchases.restore(); XCTAssertEqual(again, .success)
        XCTAssertEqual(progress.progress.coins, 1500); XCTAssertEqual(progress.progress.purchases.hints, 20)
    }
    func testRefundRevokesThemeAndRemoveAdsWithoutNegativeBalances() async throws {
        await purchases.start()
        let ads = await buy(.removeAds); XCTAssertEqual(ads, .success)
        let theme = await buy(.theme); XCTAssertEqual(theme, .success)
        progress.selectPremiumTheme(true)
        for transaction in session.allTransactions() { try session.refundTransaction(identifier: transaction.identifier) }
        // Refund delivery and StoreKit's cached current-entitlement snapshot settle
        // asynchronously. Exercise the same reconciliation used on foregrounding.
        for _ in 0..<100 {
            await purchases.reconcile()
            if !progress.progress.purchases.removesAds && !progress.progress.purchases.ownsTheme { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertFalse(progress.progress.purchases.removesAds)
        XCTAssertFalse(progress.progress.purchases.ownsTheme)
        XCTAssertFalse(progress.progress.purchases.premiumThemeSelected)
        XCTAssertEqual(progress.progress.coins, 0)
    }
    func testUnverifiedTransactionNeverGrantsOrFinishes() async throws {
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        let result = await buy(.coins)
        guard case .failed = result else { return XCTFail("Unverified transaction must fail") }
        XCTAssertEqual(progress.progress.coins, 0); XCTAssertTrue(progress.progress.purchases.fulfilled.isEmpty)
        var unfinished = 0
        for await _ in Transaction.unfinished { unfinished += 1 }
        XCTAssertGreaterThan(unfinished, 0, "Unverified purchase must remain unfinished")
    }
}
