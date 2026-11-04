import SwiftUI
import PuzzleCore

@MainActor
final class ProgressModel: ObservableObject {
    @Published private(set) var progress = PlayerProgress()
    @Published private(set) var manager: LevelManager?
    @Published private(set) var error: String?
    private let telemetry: Telemetry
    private let store: any PlayerSaveService
    private var canSave = false

    init(saveService: (any PlayerSaveService)? = nil, campaign: LevelManager? = nil, enableDebugFixtures: Bool = true, telemetry: Telemetry = .shared) {
        self.telemetry = telemetry
        store = saveService ?? Self.defaultStore()
        do { manager = try campaign ?? LevelManager.bundled() }
        catch { telemetry.diagnose(.campaignLoad); self.error = "Unable to load levels: \(error.localizedDescription)"; return }
        do {
            progress = try store.load(campaign: manager); canSave = true
            var funded = progress
            if funded.claimRestorationFunding() > 0 { _ = commit(funded) }
            #if DEBUG
            if enableDebugFixtures, let namespace = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"], UUID(uuidString: namespace) != nil,
               let mode = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_CAMPAIGN"], let manager {
                if ["completed", "restoration-funded", "restoration-starter"].contains(mode) ||
                    (mode == "restoration-budget" && progress.bestMoves.isEmpty) {
                    let count = mode == "restoration-budget" ? 8 : (mode == "restoration-starter" ? 0 : 100)
                    for level in manager.levels.prefix(count) {
                        guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { continue }
                        var session = PuzzleSession(state: level.state)
                        for move in moves { session.move(from: move.source, to: move.destination) }
                        progress.complete(level: level, session: session)
                    }
                    if mode == "restoration-budget", let file = store as? ProgressStore {
                        // A historical eight-clear wallet, isolated to this UUID test save.
                        struct OldProgress: Encodable {
                            let bestMoves: [Int: Int]; let stars: [Int: Int]; let unlockedLevels: Set<Int>
                            let rewardedLevels: Set<Int>; let legacyBestMoves: [Int: Int]; let legacyCoins: Int
                        }
                        struct OldSave: Encodable { let version = 2; let progress: OldProgress }
                        let old = OldProgress(bestMoves: progress.bestMoves, stars: progress.stars, unlockedLevels: progress.unlockedLevels, rewardedLevels: progress.rewardedLevels, legacyBestMoves: [:], legacyCoins: 0)
                        try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try JSONEncoder().encode(OldSave(progress: old)).write(to: file.url, options: .atomic)
                        progress = try file.load(campaign: manager)
                        _ = progress.restore(.pathways)
                    }
                    if mode == "restoration-funded" || mode == "restoration-starter" {
                        try progress.fulfillPurchase(id: "fixture.coins.1", item: .coins, revoked: false)
                    }
                    try store.save(progress)
                }
            }
            #endif
        } catch { telemetry.diagnose(.saveRead); self.error = "Saved progress could not be read. Your save has been preserved. \(error.localizedDescription)" }
    }
    private static func defaultStore() -> ProgressStore {
        let directory = URL.applicationSupportDirectory.appending(path: "SortScape", directoryHint: .isDirectory)
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"], UUID(uuidString: id) != nil {
            return ProgressStore(url: directory.appending(path: "UITests/\(id).json"))
        }
        #endif
        return ProgressStore(url: directory.appending(path: "progress.json"))
    }
    func complete(level: Level, session: PuzzleSession) -> RewardReceipt {
        guard canSave else { return RewardReceipt() }
        var updated = progress
        let receipt = updated.completeWithReceipt(level: level, session: session)
        guard commit(updated) else { return RewardReceipt() }
        return receipt
    }
    func restore(_ id: DecorationID) -> RestorationResult {
        guard canSave else { return .invalidTransaction }
        var updated = progress
        let result = updated.restore(id)
        if case .restored = result { guard commit(updated) else { return .invalidTransaction } }
        return result
    }
    func fulfillPurchase(id: String, item: StoreItem, revoked: Bool, reportPurchase: Bool = true) throws {
        guard canSave else { throw FulfillmentError.storageUnavailable }
        var updated = progress
        try updated.fulfillPurchase(id: id, item: item, revoked: revoked)
        guard updated == progress || commit(updated, reportPurchases: reportPurchase) else { throw FulfillmentError.storageUnavailable }
    }
    func reconcilePurchases(_ active: Set<StoreItem>) throws {
        guard canSave else { throw FulfillmentError.storageUnavailable }
        var updated = progress
        try updated.reconcilePurchases(active)
        guard updated == progress || commit(updated) else { throw FulfillmentError.storageUnavailable }
    }
    func useHint(in levelID: Int, spendingToken: Bool = false) -> Bool {
        guard canSave else { return false }
        var updated = progress
        guard updated.useHint(in: levelID, spendingToken: spendingToken) else { return false }
        return commit(updated)
    }
    func selectPremiumTheme(_ selected: Bool) {
        guard canSave else { return }
        var updated = progress
        if updated.selectPremiumTheme(selected) { _ = commit(updated) }
    }
    @discardableResult
    func claimAdReward(id: String, reward: AdReward) throws -> Bool {
        guard canSave else { throw FulfillmentError.storageUnavailable }
        var updated = progress
        let granted = try updated.claimAdReward(id: id, reward: reward)
        guard updated == progress || commit(updated) else { throw FulfillmentError.storageUnavailable }
        return granted
    }
    func consumeAdUndo() -> Bool {
        guard canSave else { return false }
        var updated = progress
        guard updated.consumeAdUndo() else { return false }
        return commit(updated)
    }
    private func commit(_ updated: PlayerProgress, reportPurchases: Bool = true) -> Bool {
        do {
            try store.save(updated)
            let before = progress
            progress = updated; error = nil
            telemetry.economy(before: before, after: updated, reportPurchases: reportPurchases)
            return true
        } catch {
            telemetry.diagnose(.saveWrite)
            self.error = "Your changes could not be saved. No currency was taken or added. Please try again."
            return false
        }
    }
}
