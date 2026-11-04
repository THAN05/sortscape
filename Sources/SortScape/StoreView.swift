import SwiftUI
import StoreKit
import PuzzleCore

@MainActor
final class StoreModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var busy = false
    @Published private(set) var message = "All worlds and restoration plans can be completed for free."
    private var manager: StoreKitPurchaseManager?
    private var observer: Task<Void, Never>?
    private var started = false
    deinit { observer?.cancel() }
    private(set) var catalog: StoreCatalog?
    private static var localStoreEnabled: Bool { true }
    func start(progress: ProgressModel) async {
        guard !started else { return }; started = true
        #if DEBUG && targetEnvironment(simulator)
        do {
            let catalog = try StoreCatalog.bundled(); self.catalog = catalog
            let enabled = Self.localStoreEnabled, localOnly = true
            let service = StoreKitPurchaseManager(catalog: catalog, progress: progress, permitsPurchases: enabled, localOnly: localOnly)
            manager = service
            observer = Task { [weak self] in
                for await outcome in service.events {
                    guard !Task.isCancelled else { return }
                    self?.announce(outcome.message)
                }
            }
            await service.start()
            if enabled { await reload() }
            else { announce("Purchases are disabled while the store is being prepared for release.") }
        } catch { announce("Store configuration is unavailable. Your game progress is unaffected.") }
        #else
        announce("Purchases are unavailable in this version. All worlds and restoration plans are free to play.")
        #endif
    }
    func reload() async {
        guard let manager, !busy else { return }
        busy = true; defer { busy = false }
        do {
            products = try await manager.loadProducts()
            if products.count != StoreItem.allCases.count { announce("Some products are unavailable. Please try again later.") }
        } catch { announce("The store could not load. Check your connection and try again.") }
    }
    func buy(_ item: StoreItem) async {
        guard let manager, !busy else { return }
        busy = true; defer { busy = false }
        Telemetry.shared.emit(AnalyticsEvent(name: .purchaseStarted, parameters: ["item": .text(item.rawValue)]))
        let outcome = await manager.purchase(item)
        if case .failed = outcome { Telemetry.shared.emit(AnalyticsEvent(name: .purchaseFailed, parameters: ["item": .text(item.rawValue), "reason": .text("store_error")])) }
        announce(outcome.message)
    }
    func restore() async {
        guard let manager, !busy else { return }
        busy = true; defer { busy = false }
        let result = await manager.restore()
        announce(result == .success ? "Purchases restored. Finished coin and hint packs are not restored." : result.message)
    }
    func refreshEntitlements() async { await manager?.start() }
    private func announce(_ text: String) {
        message = text; UIAccessibility.post(notification: .announcement, argument: text)
    }
    func product(_ item: StoreItem) -> Product? { products.first { $0.id == catalog?.identifiers[item] } }
}

struct StoreView: View {
    @EnvironmentObject private var progress: ProgressModel
    @EnvironmentObject private var store: StoreModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CurrencyBalanceView(coins: progress.progress.coins, stars: progress.progress.starBalance)
                Label("\(progress.progress.availableHints) hint tokens", systemImage: "lightbulb.fill").font(.headline).accessibilityIdentifier("hint-balance")
                Text("A little extra possibility").font(.system(.largeTitle, design: .rounded).bold())
                Text("Optional extras for your escape. Every puzzle and restoration plan remains free to complete.").foregroundStyle(ScapeTheme.teal)
                Text(store.message).font(.subheadline).accessibilityIdentifier("store-message")
                if store.busy { ProgressView("Contacting Apple…") }
                ForEach(StoreItem.allCases, id: \.self) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(store.product(item)?.displayName ?? item.title, systemImage: item.symbol).font(.system(.title3, design: .rounded).bold())
                        Text(item.details).font(.subheadline)
                        if let product = store.product(item) {
                            Text(product.description).font(.caption).foregroundStyle(ScapeTheme.teal)
                            Button(owned(item) ? "Owned" : "Buy · \(product.displayPrice)") { Task { await store.buy(item) } }
                                .buttonStyle(ScapeButtonStyle()).disabled(store.busy || owned(item))
                                .accessibilityIdentifier("buy-\(item.rawValue)")
                                .accessibilityLabel("\(product.displayName), \(owned(item) ? "owned" : product.displayPrice)")
                        } else { Text("Currently unavailable").font(.caption).foregroundStyle(.secondary) }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 24))
                }
                Button("Restore Purchases") { Task { await store.restore() } }.buttonStyle(ScapeButtonStyle(secondary: true))
                    .disabled(store.busy).accessibilityIdentifier("restore-purchases")
                Button("Refresh store") { Task { await store.reload() } }.frame(minHeight: 44).disabled(store.busy)
                Text("One-time purchases; no subscriptions. Payment is charged to your Apple Account after confirmation. Coin and hint packs are consumable and cannot be restored once delivered. Keep your local save: deleting it may lose consumables and one-time bundle rewards. Non-consumable access can be restored with the same Apple Account. Refunds revoke entitlement access; already delivered currency is not deducted.").font(.footnote).foregroundStyle(ScapeTheme.teal)
                Link("Apple purchase terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/")!).frame(minHeight: 44)
                Link("Request purchase support or a refund", destination: URL(string: "https://reportaproblem.apple.com/")!).frame(minHeight: 44)
                #if DEBUG
                Text("Development: use the SortScape Local Store scheme. Only Xcode StoreKit transactions are accepted; no real purchases.").font(.caption)
                #endif
            }.padding(20).frame(maxWidth: 560)
        }.frame(maxWidth: .infinity).background(ScapeTheme.cream).foregroundStyle(ScapeTheme.ink)
            .navigationTitle("SortScape store").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
    private func owned(_ item: StoreItem) -> Bool {
        item == .removeAds ? progress.progress.purchases.removesAds : (!item.consumable && progress.progress.purchases.entitlements.contains(item))
    }
}

extension StoreItem {
    var title: String {
        switch self { case .removeAds: "Remove Ads"; case .coins: "1,000 Coins"; case .hints: "10 Hints"; case .starter: "Starter Bundle"; case .theme: "Premium Island Theme" }
    }
    var symbol: String {
        switch self { case .removeAds: "hand.raised.fill"; case .coins: "sun.max.fill"; case .hints: "lightbulb.fill"; case .starter: "gift.fill"; case .theme: "moon.stars.fill" }
    }
    var details: String {
        switch self {
        case .removeAds: "Removes automatic ads. Voluntary reward ads remain available only when you choose them."
        case .coins: "1,000 coins for optional island restoration."
        case .hints: "10 automatic move assists. Each level allows one hint. Use a free hint or spend a token to apply the move automatically."
        case .starter: "Ad-removal access, plus 1,500 coins and 20 hint tokens once per local player save. Bundle rewards do not repeat on restore or repurchase."
        case .theme: "Own the Moonlit Lagoon cosmetic. Switch themes on your island; puzzles and rewards stay the same."
        }
    }
}
