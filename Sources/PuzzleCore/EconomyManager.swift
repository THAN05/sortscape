/// A bounded, Codable, pure Swift transaction ledger. IDs are stable domain keys,
/// so retrying an identical operation is harmless even after a process restart.
public struct EconomyTransaction: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case award, spend, migration }
    public let id: String
    public let kind: Kind
    public let coins: Int
    public let stars: Int
}
public enum EconomyResult: Equatable, Sendable {
    case applied, duplicate, conflict, insufficientFunds, invalidTransaction
}
public struct EconomyManager: Codable, Equatable, Sendable {
    public private(set) var transactions: [String: EconomyTransaction] = [:]
    public init() {}
    public var coins: Int { lifetimeCoinsEarned - lifetimeCoinsSpent }
    public var stars: Int { lifetimeStarsEarned - lifetimeStarsSpent }
    public var lifetimeCoinsEarned: Int { transactions.values.reduce(0) { $0 + max(0, $1.coins) } }
    public var lifetimeCoinsSpent: Int { transactions.values.reduce(0) { $0 + max(0, -$1.coins) } }
    public var lifetimeStarsEarned: Int { transactions.values.reduce(0) { $0 + max(0, $1.stars) } }
    public var lifetimeStarsSpent: Int { transactions.values.reduce(0) { $0 + max(0, -$1.stars) } }

    @discardableResult
    public mutating func award(id: String, coins: Int, stars: Int = 0) -> EconomyResult {
        apply(id: id, kind: .award, coins: coins, stars: stars)
    }
    @discardableResult
    public mutating func spend(id: String, coins: Int, stars: Int = 0) -> EconomyResult {
        guard coins >= 0, stars >= 0, coins <= 100_000, stars <= 100_000, coins + stars > 0 else { return .invalidTransaction }
        return apply(id: id, kind: .spend, coins: -coins, stars: -stars)
    }
    @discardableResult
    mutating func importBalance(id: String, coins: Int, stars: Int) -> EconomyResult {
        apply(id: id, kind: .migration, coins: coins, stars: stars)
    }
    private mutating func apply(id: String, kind: EconomyTransaction.Kind, coins: Int, stars: Int) -> EconomyResult {
        guard !id.isEmpty, id.utf8.count <= 128, (-100_000...100_000).contains(coins), (-100_000...100_000).contains(stars),
              kind == .spend ? (coins <= 0 && stars <= 0) : (coins >= 0 && stars >= 0) else { return .invalidTransaction }
        let transaction = EconomyTransaction(id: id, kind: kind, coins: coins, stars: stars)
        if let existing = transactions[id] { return existing == transaction ? .duplicate : .conflict }
        guard transactions.count < 100_000 else { return .invalidTransaction }
        guard self.coins + coins >= 0, self.stars + stars >= 0 else { return .insufficientFunds }
        transactions[id] = transaction
        return .applied
    }
    var isValid: Bool {
        guard transactions.count <= 100_000 else { return false }
        for (id, value) in transactions {
            guard id == value.id, !id.isEmpty, id.utf8.count <= 128,
                  (-100_000...100_000).contains(value.coins), (-100_000...100_000).contains(value.stars) else { return false }
            if value.kind == .spend {
                guard value.coins <= 0, value.stars <= 0, value.coins < 0 || value.stars < 0 else { return false }
            } else if value.coins < 0 || value.stars < 0 { return false }
        }
        return coins >= 0 && stars >= 0
    }
}

public struct RewardReceipt: Equatable, Sendable {
    public var baseCoins = 0
    public var efficiencyCoins = 0
    public var milestoneCoins = 0
    public var starsEarned = 0
    public var rating = 0
    public var coinsEarned: Int { baseCoins + efficiencyCoins + milestoneCoins }
    public init() {}
}

public enum MilestoneRewards {
    public static let levels = [5: 25, 10: 50, 20: 75, 40: 100, 65: 125, 85: 150, 100: 200]
    public static let restorationFunding = [8: 1000, 25: 4200, 40: 4300, 60: 5000, 80: 5500, 100: 6765]
    public static let island = [2: 20, 5: 40, 10: 75]
}
