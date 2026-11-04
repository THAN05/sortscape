import Foundation
import StoreKit
import PuzzleCore

struct StoreCatalog: Sendable {
    let identifiers: [StoreItem: String]
    init(identifiers: [StoreItem: String]) {
        precondition(identifiers.count == StoreItem.allCases.count && Set(identifiers.values).count == identifiers.count)
        self.identifiers = identifiers
    }
    static func bundled() throws -> StoreCatalog {
        guard let url = Bundle.main.url(forResource: "StoreProducts", withExtension: "json") else { throw FulfillmentError.invalidTransaction }
        let raw = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        var ids: [StoreItem: String] = [:]
        for item in StoreItem.allCases {
            guard let id = raw[item.rawValue], !id.isEmpty else { throw FulfillmentError.invalidTransaction }
            ids[item] = id
        }
        guard Set(ids.values).count == ids.count else { throw FulfillmentError.invalidTransaction }
        return StoreCatalog(identifiers: ids)
    }
    func item(for identifier: String) -> StoreItem? { identifiers.first { $0.value == identifier }?.key }
}

enum PurchaseOutcome: Equatable, Sendable {
    case success, pending, cancelled, failed(String)
    var message: String {
        switch self {
        case .success: "Purchase delivered. Thank you for supporting SortScape!"
        case .pending: "Awaiting approval. Rewards arrive only after Apple confirms the purchase."
        case .cancelled: "Purchase cancelled. No rewards were added."
        case .failed(let reason): reason
        }
    }
}

/// StoreKit facts cross this actor only after Apple's signature verification.
/// Durable fulfillment and its transaction marker are committed together before finish().
actor StoreKitPurchaseManager {
    private let catalog: StoreCatalog
    private let progress: ProgressModel
    private let permitsPurchases: Bool
    private let localOnly: Bool
    private var listener: Task<Void, Never>?
    private var purchasing = false
    private var revision = 0
    private var products: [String: Product] = [:]
    private let continuation: AsyncStream<PurchaseOutcome>.Continuation
    let events: AsyncStream<PurchaseOutcome>

    init(catalog: StoreCatalog, progress: ProgressModel, permitsPurchases: Bool, localOnly: Bool = true) {
        self.catalog = catalog; self.progress = progress
        self.permitsPurchases = permitsPurchases; self.localOnly = localOnly
        let stream = AsyncStream<PurchaseOutcome>.makeStream(bufferingPolicy: .bufferingNewest(10))
        events = stream.stream; continuation = stream.continuation
    }
    deinit { listener?.cancel(); continuation.finish() }
    func start() async {
        if listener == nil {
            listener = Task { [weak self] in
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { return }
                    guard let self else { return }
                    let outcome = await self.process(result)
                    await self.emit(outcome)
                    await self.reconcile()
                }
            }
        }
        await recoverUnfinished()
        await reconcile()
    }
    func stop() { listener?.cancel(); listener = nil }
    private func emit(_ value: PurchaseOutcome) { continuation.yield(value) }
    func loadProducts() async throws -> [Product] {
        let loaded = try await Product.products(for: Array(catalog.identifiers.values))
        products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        return StoreItem.allCases.compactMap { catalog.identifiers[$0].flatMap { products[$0] } }
    }
    func purchase(_ item: StoreItem) async -> PurchaseOutcome {
        guard permitsPurchases else { return .failed("Purchases are disabled in this build. Use the local StoreKit testing scheme.") }
        guard !purchasing else { return .failed("Another purchase or restore is in progress.") }
        guard let id = catalog.identifiers[item], let product = products[id] else { return .failed("Product unavailable. Refresh the store and try again.") }
        guard product.type == (item.consumable ? .consumable : .nonConsumable) else {
            return .failed("Product configuration does not match this offer. No purchase was attempted.")
        }
        purchasing = true; defer { purchasing = false }
        do {
            return await handle(try await product.purchase())
        } catch StoreKitError.userCancelled { return .cancelled }
        catch { return .failed("Purchase failed: \(error.localizedDescription)") }
    }
    // Shared result handler keeps all StoreKit return paths explicit and testable.
    func handle(_ result: Product.PurchaseResult) async -> PurchaseOutcome {
        switch result {
        case .success(let verification): return await process(verification)
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: return .failed("Apple returned an unknown purchase status. Please try Restore Purchases.")
        }
    }
    @discardableResult
    private func process(_ result: VerificationResult<Transaction>, reportPurchase: Bool = true) async -> PurchaseOutcome {
        guard case .verified(let transaction) = result else { return .failed("Apple could not verify this purchase. Nothing was granted. Try Restore Purchases.") }
        guard !localOnly || transaction.environment == .xcode else { return .failed("This development build accepts only local StoreKit test transactions.") }
        guard let item = catalog.item(for: transaction.productID),
              transaction.productType == (item.consumable ? .consumable : .nonConsumable),
              transaction.purchasedQuantity == 1 else { return .failed("This transaction does not match the supported catalog. It remains unfinished.") }
        revision += 1
        let key = "\(transaction.environment.rawValue).\(transaction.id)"
        do {
            try await progress.fulfillPurchase(id: key, item: item, revoked: transaction.revocationDate != nil, reportPurchase: reportPurchase)
            await transaction.finish()
            return transaction.revocationDate == nil ? .success : .failed("A purchase was refunded or revoked. Its entitlement has been removed.")
        } catch { return .failed("Purchase received but could not be saved. It remains pending delivery; reopen the app or tap Restore Purchases to retry.") }
    }
    @discardableResult
    func recoverUnfinished() async -> Bool {
        var delivered = true
        for await result in Transaction.unfinished {
            let outcome = await process(result)
            if case .failed = outcome { emit(outcome); delivered = false }
        }
        return delivered
    }
    @discardableResult
    func reconcile() async -> Bool {
        let startRevision = revision
        var active: Set<StoreItem> = []
        var processedEntitlements = 0
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                emit(.failed("An entitlement could not be verified. Existing ownership was preserved; please retry restore.")); return false
            }
            guard !localOnly || transaction.environment == .xcode else { continue }
            guard let item = catalog.item(for: transaction.productID), !item.consumable,
                  transaction.productType == .nonConsumable, transaction.revocationDate == nil else { continue }
            processedEntitlements += 1
            if case .failed(let reason) = await process(result, reportPurchase: false) { emit(.failed(reason)); return false }
            let key = "\(transaction.environment.rawValue).\(transaction.id)"
            let record = await progress.progress.purchases.fulfilled[key]
            if record?.revoked != true { active.insert(item) }
        }
        // process() increments revision for each entitlement we handled. Updates/purchases
        // interleaved with this scan invalidate the snapshot; retry on the next foreground.
        guard revision == startRevision + processedEntitlements else { return false }
        do { try await progress.reconcilePurchases(active); return true }
        catch { emit(.failed("Ownership could not be saved. Please retry Restore Purchases.")); return false }
    }
    func restore() async -> PurchaseOutcome {
        guard permitsPurchases, !purchasing else { return .failed("Restore is unavailable or another purchase is in progress.") }
        purchasing = true; defer { purchasing = false }
        do {
            try await AppStore.sync()
            let delivered = await recoverUnfinished(), reconciled = await reconcile()
            return delivered && reconciled ? .success : .failed("Some purchases could not be delivered or saved. Please retry Restore Purchases.")
        } catch StoreKitError.userCancelled { return .cancelled }
        catch { return .failed("Restore failed: \(error.localizedDescription)") }
    }
}
