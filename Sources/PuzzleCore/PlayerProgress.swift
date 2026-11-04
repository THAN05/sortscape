import Foundation

public struct PlayerProgress: Codable, Equatable, Sendable {
    public private(set) var bestMoves: [Int: Int] = [:]
    public private(set) var stars: [Int: Int] = [:]
    public private(set) var unlockedLevels: Set<Int> = [1]
    public private(set) var rewardedLevels: Set<Int> = []
    /// Historical scores remain available even for boards not selected in the new campaign.
    public private(set) var legacyBestMoves: [Int: Int] = [:]
    public private(set) var legacyCoins = 0
    public private(set) var economy = EconomyManager()
    public private(set) var island = IslandProgress()
    private var adRewardState: AdRewardState? = AdRewardState()
    public var adRewards: AdRewardState { adRewardState ?? AdRewardState() }
    public var hasAdRewardJournal: Bool { adRewardState != nil }
    // Optional for compatibility with saves written before the per-level limit.
    private var hintedLevels: Set<Int>?
    public func hasUsedHint(in levelID: Int) -> Bool { hintedLevels?.contains(levelID) == true }

    public mutating func useHint(in levelID: Int, spendingToken: Bool) -> Bool {
        guard isUnlocked(levelID), !hasUsedHint(in: levelID) else { return false }
        if spendingToken && !consumeHint() { return false }
        hintedLevels = (hintedLevels ?? []).union([levelID])
        return true
    }

    public var availableHints: Int { purchases.hints + adRewards.hints }
    public mutating func initializeAdRewardJournal() { if adRewardState == nil { adRewardState = AdRewardState() } }
    @discardableResult
    public mutating func claimAdReward(id: String, reward: AdReward) throws -> Bool {
        var updated = self, journal = adRewards
        guard UUID(uuidString: id) != nil, journal.claims.count < 100_000 else { throw FulfillmentError.invalidTransaction }
        if let existing = journal.claims[id] {
            guard existing == reward else { throw FulfillmentError.conflictingTransaction }
            return false
        }
        if case .levelCoins(let level) = reward {
            guard isCompleted(level) else { throw FulfillmentError.invalidTransaction }
            if journal.hasBonus(for: level) { return false }
            guard updated.economy.award(id: "ad.\(id)", coins: 25) == .applied else { throw FulfillmentError.invalidTransaction }
        }
        journal.claims[id] = reward; updated.adRewardState = journal
        guard updated.isValid else { throw FulfillmentError.invalidTransaction }
        self = updated; return true
    }
    public mutating func consumeAdUndo() -> Bool {
        var journal = adRewards
        guard journal.undos > 0 else { return false }
        journal.undosUsed += 1; adRewardState = journal; return true
    }
    // Optional only to decode published v3 saves. All v4 saves require this journal.
    private var purchaseState: PurchaseState? = PurchaseState()
    public var purchases: PurchaseState { purchaseState ?? PurchaseState() }
    public var hasPurchaseJournal: Bool { purchaseState != nil }
    public mutating func initializePurchaseJournal() { if purchaseState == nil { purchaseState = PurchaseState() } }
    public mutating func fulfillPurchase(id: String, item: StoreItem, revoked: Bool) throws {
        var updated = self
        var state = updated.purchases
        try state.fulfill(id: id, item: item, revoked: revoked, economy: &updated.economy)
        updated.purchaseState = state
        guard updated.isValid else { throw FulfillmentError.invalidTransaction }
        self = updated
    }
    public mutating func reconcilePurchases(_ active: Set<StoreItem>) throws {
        guard active.allSatisfy({ !$0.consumable }) else { throw FulfillmentError.invalidTransaction }
        var state = purchases; state.entitlements = active
        if !state.ownsTheme { state.premiumThemeSelected = false }
        purchaseState = state
    }
    public mutating func consumeHint() -> Bool {
        if adRewards.hints > 0 {
            var journal = adRewards; journal.hintsUsed += 1; adRewardState = journal; return true
        }
        var state = purchases
        guard state.hints > 0 else { return false }
        state.hintsUsed += 1; purchaseState = state; return true
    }
    public mutating func selectPremiumTheme(_ selected: Bool) -> Bool {
        var state = purchases
        guard !selected || state.ownsTheme else { return false }
        state.premiumThemeSelected = selected; purchaseState = state; return true
    }
    public var coins: Int { economy.coins }
    public var starBalance: Int { economy.stars }
    public var totalStars: Int { stars.values.reduce(0, +) }
    public static let completionReward = 25
    public init() {}
    public func isUnlocked(_ id: Int) -> Bool { (1...100).contains(id) && unlockedLevels.contains(id) }
    public func isCompleted(_ id: Int) -> Bool { bestMoves[id] != nil }

    @discardableResult
    public mutating func complete(level: Level, session: PuzzleSession) -> Int {
        completeWithReceipt(level: level, session: session).coinsEarned
    }
    public mutating func completeWithReceipt(level: Level, session: PuzzleSession) -> RewardReceipt {
        guard isUnlocked(level.id), session.initialState == level.state,
              session.state.isSolved, session.moveCount > 0 else { return RewardReceipt() }
        var updated = self, receipt = RewardReceipt()
        let rating = level.stars(for: session.moveCount)
        receipt.rating = rating
        if !rewardedLevels.contains(level.id) {
            guard updated.economy.award(id: "level.\(level.id).first-clear", coins: Self.completionReward) == .applied else { return RewardReceipt() }
            updated.rewardedLevels.insert(level.id); receipt.baseCoins = Self.completionReward
        }
        let previous = stars[level.id, default: 0]
        for star in (previous + 1)..<max(previous + 1, rating + 1) {
            guard updated.economy.award(id: "level.\(level.id).star.\(star)", coins: 0, stars: 1) == .applied else { return RewardReceipt() }
            receipt.starsEarned += 1
        }
        for tier in 2...3 where previous < tier && rating >= tier {
            guard updated.economy.award(id: "level.\(level.id).efficiency.\(tier)", coins: 5) == .applied else { return RewardReceipt() }
            receipt.efficiencyCoins += 5
        }
        updated.bestMoves[level.id] = min(bestMoves[level.id] ?? Int.max, session.moveCount)
        updated.stars[level.id] = max(previous, rating)
        if level.id < 100 { updated.unlockedLevels.insert(level.id + 1) }
        receipt.milestoneCoins = updated.awardMilestones() + updated.claimRestorationFunding()
        self = updated
        return receipt
    }
    private mutating func awardMilestones() -> Int {
        var coins = 0
        for (count, amount) in MilestoneRewards.levels.sorted(by: { $0.key < $1.key }) where bestMoves.count >= count {
            if economy.award(id: "milestone.levels.\(count)", coins: amount) == .applied { coins += amount }
        }
        for (count, amount) in MilestoneRewards.island.sorted(by: { $0.key < $1.key }) where island.restored.count >= count {
            if economy.award(id: "milestone.island.\(count)", coins: amount) == .applied { coins += amount }
        }
        return coins
    }
    @discardableResult
    public mutating func claimRestorationFunding() -> Int {
        var coins = 0
        for (count, amount) in MilestoneRewards.restorationFunding where bestMoves.count >= count {
            if economy.award(id: "milestone.restoration-funding.\(count)", coins: amount) == .applied {
                coins += amount
            }
        }
        return coins
    }

    public func restorationStatus(_ item: RestorationItem) -> RestorationStatus {
        if island.restored.contains(item.id) { return .restored }
        guard bestMoves.count >= item.requiredLevels, starBalance >= item.requiredStars,
              item.prerequisite.map({ island.restored.contains($0) }) ?? true else { return .locked }
        return coins >= item.cost ? .available : .insufficientCoins
    }
    public var nextRestorationObjective: RestorationItem? {
        RestorationItem.all.first { restorationStatus($0) == .available || restorationStatus($0) == .insufficientCoins }
            ?? RestorationItem.all.first { !island.restored.contains($0.id) }
    }
    public mutating func restore(_ id: DecorationID) -> RestorationResult {
        guard let item = RestorationItem.all.first(where: { $0.id == id }) else { return .invalidTransaction }
        switch restorationStatus(item) {
        case .restored: return .alreadyRestored
        case .locked: return .locked
        case .insufficientCoins: return .insufficientCoins(needed: item.cost - coins)
        case .available: break
        }
        var updated = self
        guard updated.economy.spend(id: "restoration.\(id.rawValue)", coins: item.cost) == .applied else { return .invalidTransaction }
        updated.island.restored.insert(id)
        let bonus = updated.awardMilestones()
        self = updated
        return .restored(milestoneCoins: bonus)
    }

    mutating func importPreviousEconomy() {
        economy = EconomyManager()
        economy.importBalance(id: "migration.balance", coins: legacyCoins + rewardedLevels.count * Self.completionReward, stars: totalStars)
        for id in rewardedLevels {
            economy.award(id: "level.\(id).first-clear", coins: 0)
            for star in 1...stars[id, default: 1] { economy.award(id: "level.\(id).star.\(star)", coins: 0) }
            for tier in 2...3 where stars[id, default: 0] >= tier { economy.award(id: "level.\(id).efficiency.\(tier)", coins: 0) }
        }
        for count in MilestoneRewards.levels.keys where bestMoves.count >= count { economy.award(id: "milestone.levels.\(count)", coins: 0) }
    }

    static func migrate(_ old: [Int: Int], legacy: LevelManager, campaign: LevelManager) -> PlayerProgress {
        var result = PlayerProgress()
        result.legacyBestMoves = old
        result.unlockedLevels = Set(1...min(100, (old.keys.max() ?? 0) + 1))
        let newBoards = Dictionary(uniqueKeysWithValues: campaign.levels.map { (BoardIdentity.canonical($0.state), $0) })
        for previous in legacy.levels {
            guard let moves = old[previous.id], let current = newBoards[BoardIdentity.canonical(previous.state)] else { continue }
            result.bestMoves[current.id] = min(result.bestMoves[current.id] ?? Int.max, moves)
            result.stars[current.id] = max(result.stars[current.id] ?? 0, current.stars(for: moves))
            result.unlockedLevels.insert(current.id)
            result.rewardedLevels.insert(current.id)
        }
        result.legacyCoins = (old.count - result.rewardedLevels.count) * completionReward
        result.importPreviousEconomy()
        return result
    }

    fileprivate static func upgraded(_ old: VersionTwoProgress) throws -> PlayerProgress {
        var progress = PlayerProgress()
        progress.bestMoves = old.bestMoves; progress.stars = old.stars
        progress.unlockedLevels = old.unlockedLevels; progress.rewardedLevels = old.rewardedLevels
        progress.legacyBestMoves = old.legacyBestMoves; progress.legacyCoins = old.legacyCoins
        guard progress.progressionFieldsValid else { throw CocoaError(.fileReadCorruptFile) }
        progress.importPreviousEconomy()
        guard progress.isValid else { throw CocoaError(.fileReadCorruptFile) }
        return progress
    }
    private var progressionFieldsValid: Bool {
        bestMoves.allSatisfy { (1...100).contains($0.key) && $0.value > 0 } &&
        stars.allSatisfy { (1...100).contains($0.key) && (1...3).contains($0.value) } &&
        Set(bestMoves.keys) == Set(stars.keys) && rewardedLevels == Set(bestMoves.keys) &&
        unlockedLevels.contains(1) && unlockedLevels.allSatisfy { (1...100).contains($0) } &&
        rewardedLevels.isSubset(of: unlockedLevels) && legacyBestMoves.allSatisfy { (1...15).contains($0.key) && $0.value > 0 } &&
        legacyCoins >= 0 && legacyCoins <= 375 && legacyCoins % Self.completionReward == 0
    }
    var isValid: Bool {
        guard (hintedLevels ?? []).isSubset(of: unlockedLevels), progressionFieldsValid, economy.isValid, purchases.isValid, adRewards.isValid, economy.lifetimeStarsEarned == totalStars else { return false }
        var bonusLevels: Set<Int> = []
        for (id, reward) in adRewards.claims {
            if case .levelCoins(let level) = reward {
                guard isCompleted(level), bonusLevels.insert(level).inserted,
                      economy.transactions["ad.\(id)"]?.coins == 25,
                      economy.transactions["ad.\(id)"]?.kind == .award else { return false }
            }
        }
        for item in RestorationItem.all {
            if island.restored.contains(item.id) {
                guard let transaction = economy.transactions["restoration.\(item.id.rawValue)"], transaction.kind == .spend,
                      transaction.stars == 0,
                      item.prerequisite.map({ island.restored.contains($0) }) ?? true else { return false }
                if let previous = item.previousTerms, transaction.coins == -previous.cost {
                    guard bestMoves.count >= previous.requiredClears, totalStars >= previous.requiredClears else { return false }
                } else {
                    guard (transaction.coins == -item.cost || transaction.coins == -item.preIncreaseCost),
                          bestMoves.count >= item.requiredLevels,
                          totalStars >= item.requiredStars else { return false }
                }
            } else if economy.transactions["restoration.\(item.id.rawValue)"] != nil { return false }
        }
        return true
    }

}

public protocol PlayerSaveService: Sendable {
    func load(campaign: LevelManager?) throws -> PlayerProgress
    func save(_ progress: PlayerProgress) throws
}

private struct VersionTwoProgress: Decodable {
    let bestMoves: [Int: Int]
    let stars: [Int: Int]
    let unlockedLevels: Set<Int>
    let rewardedLevels: Set<Int>
    let legacyBestMoves: [Int: Int]
    let legacyCoins: Int
    func migrated() throws -> PlayerProgress { try PlayerProgress.upgraded(self) }

}

public struct ProgressStore: PlayerSaveService {
    public let url: URL
    public init(url: URL) { self.url = url }
    private struct Header: Decodable { let version: Int }
    private struct Save: Codable { let version: Int; let progress: PlayerProgress }
    private struct LegacySave: Decodable {
        struct Progress: Decodable { let bestMoves: [Int: Int] }
        let progress: Progress
    }
    public func load(campaign: LevelManager? = nil) throws -> PlayerProgress {
        guard FileManager.default.fileExists(atPath: url.path) else { return PlayerProgress() }
        let data = try Data(contentsOf: url), decoder = JSONDecoder()
        switch try decoder.decode(Header.self, from: data).version {
        case 1:
            let old = try decoder.decode(LegacySave.self, from: data).progress.bestMoves
            guard old.allSatisfy({ (1...15).contains($0.key) && $0.value > 0 }) else { throw CocoaError(.fileReadCorruptFile) }
            let current: LevelManager
            if let campaign { current = campaign } else { current = try LevelManager.bundled() }
            return PlayerProgress.migrate(old, legacy: try LevelManager.legacyBundled(), campaign: current)
        case 2:
            struct OldSave: Decodable { let progress: VersionTwoProgress }
            return try decoder.decode(OldSave.self, from: data).progress.migrated()
        case 3, 4, 5:
            var progress = try decoder.decode(Save.self, from: data).progress
            let version = try decoder.decode(Header.self, from: data).version
            guard version < 4 || progress.hasPurchaseJournal else { throw CocoaError(.fileReadCorruptFile) }
            guard progress.isValid else { throw CocoaError(.fileReadCorruptFile) }
            guard version < 5 || progress.hasAdRewardJournal else { throw CocoaError(.fileReadCorruptFile) }
            progress.initializeAdRewardJournal()
            progress.initializePurchaseJournal()
            return progress
        default: throw CocoaError(.fileReadCorruptFile)
        }
    }
    public func save(_ progress: PlayerProgress) throws {
        guard progress.isValid, progress.hasPurchaseJournal, progress.hasAdRewardJournal else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: url), (try? JSONDecoder().decode(Header.self, from: data).version).map({ $0 == 1 || $0 == 2 || $0 == 3 || $0 == 4 }) == true {
            let version = try JSONDecoder().decode(Header.self, from: data).version
            let backup = url.appendingPathExtension("v\(version).backup")
            if !FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.copyItem(at: url, to: backup) }
        }
        try JSONEncoder().encode(Save(version: 5, progress: progress)).write(to: url, options: .atomic)
    }
}
