import Foundation

/// Stable fulfillment keys, independent of App Store identifiers and StoreKit.
public enum StoreItem: String, Codable, CaseIterable, Sendable {
    case removeAds, coins, hints, starter, theme
    public var consumable: Bool { self == .coins || self == .hints }
    public var coins: Int { self == .coins ? 1000 : (self == .starter ? 1500 : 0) }
    public var hints: Int { self == .hints ? 10 : (self == .starter ? 20 : 0) }
}
public struct PurchaseRecord: Codable, Equatable, Sendable {
    public let item: StoreItem
    public var revoked: Bool
}
public enum FulfillmentError: Error, Equatable { case invalidTransaction, conflictingTransaction, storageUnavailable }

/// This is a local receipt journal, not a cryptographic source of ownership.
/// Only the StoreKit adapter may submit verified transaction facts to this model.
public struct PurchaseState: Codable, Equatable, Sendable {
    public internal(set) var fulfilled: [String: PurchaseRecord] = [:]
    public internal(set) var entitlements: Set<StoreItem> = []
    public internal(set) var starterClaimed = false
    public internal(set) var hintsGranted = 0
    public internal(set) var hintsUsed = 0
    public internal(set) var premiumThemeSelected = false
    public var hints: Int { hintsGranted - hintsUsed }
    public var removesAds: Bool { entitlements.contains(.removeAds) || entitlements.contains(.starter) }
    public var ownsTheme: Bool { entitlements.contains(.theme) }
    public init() {}
    var isValid: Bool {
        fulfilled.count <= 100_000 && fulfilled.allSatisfy { !$0.key.isEmpty && $0.key.utf8.count <= 100 } &&
        entitlements.allSatisfy { !$0.consumable } && hintsGranted >= 0 && hintsGranted <= 2_000_000 &&
        hintsUsed >= 0 && hintsUsed <= hintsGranted && (!premiumThemeSelected || ownsTheme)
    }
    mutating func fulfill(id: String, item: StoreItem, revoked: Bool, economy: inout EconomyManager) throws {
        guard !id.isEmpty, id.utf8.count <= 100, fulfilled.count < 100_000 || fulfilled[id] != nil else { throw FulfillmentError.invalidTransaction }
        if let record = fulfilled[id], record.item != item { throw FulfillmentError.conflictingTransaction }
        if revoked || fulfilled[id]?.revoked == true {
            fulfilled[id] = PurchaseRecord(item: item, revoked: true)
            if !item.consumable { entitlements.remove(item) }
            if !ownsTheme { premiumThemeSelected = false }
            return
        }
        if fulfilled[id] == nil {
            let shouldGrant = item != .starter || !starterClaimed
            if shouldGrant {
                if item.coins > 0 {
                    guard economy.award(id: "iap.\(id)", coins: item.coins) == .applied else { throw FulfillmentError.conflictingTransaction }
                }
                guard hintsGranted <= 2_000_000 - item.hints else { throw FulfillmentError.invalidTransaction }
                hintsGranted += item.hints
                if item == .starter { starterClaimed = true }
            }
            fulfilled[id] = PurchaseRecord(item: item, revoked: false)
        }
        if !item.consumable { entitlements.insert(item) }
    }
}
