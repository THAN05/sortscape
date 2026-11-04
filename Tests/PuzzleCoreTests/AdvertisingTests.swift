import Foundation
import XCTest
@testable import PuzzleCore

final class AdvertisingTests: XCTestCase {
    func testRewardCallbacksAreIdempotentAndConflictSafe() throws {
        var progress = PlayerProgress()
        let ticket = UUID().uuidString
        XCTAssertTrue(try progress.claimAdReward(id: ticket, reward: .hint))
        XCTAssertFalse(try progress.claimAdReward(id: ticket, reward: .hint))
        XCTAssertThrowsError(try progress.claimAdReward(id: ticket, reward: .undo))
        XCTAssertEqual(progress.availableHints, 1); XCTAssertEqual(progress.coins, 0)
        XCTAssertTrue(progress.consumeHint()); XCTAssertFalse(progress.consumeHint())
        XCTAssertTrue(try progress.claimAdReward(id: UUID().uuidString, reward: .undo))
        XCTAssertTrue(progress.consumeAdUndo()); XCTAssertFalse(progress.consumeAdUndo())
        XCTAssertTrue(progress.isValid)
    }
    func testBonusRequiresCompletedLevelAndNeverRepeatsOnReplay() throws {
        var progress = PlayerProgress()
        XCTAssertThrowsError(try progress.claimAdReward(id: UUID().uuidString, reward: .levelCoins(1)))
        let level = try LevelManager.bundled().levels[0]
        var session = PuzzleSession(state: level.state)
        guard case .solved(let solution) = PuzzleSolver().solve(level.state) else { return XCTFail("Missing solution") }
        for move in solution { session.move(from: move.source, to: move.destination) }
        progress.complete(level: level, session: session)
        XCTAssertTrue(try progress.claimAdReward(id: UUID().uuidString, reward: .levelCoins(1)))
        XCTAssertFalse(try progress.claimAdReward(id: UUID().uuidString, reward: .levelCoins(1)))
        progress.complete(level: level, session: session)
        XCTAssertEqual(progress.coins, 60)
        XCTAssertTrue(progress.isValid)
    }
    func testInterstitialFirstSessionTimingPlacementOwnershipAndGlobalCaps() {
        var policy = AdFrequencyManager()
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        policy.beginSession(at: start)
        XCTAssertFalse(policy.allowsInterstitial(completedLevels: 100, betweenLevels: true, removesAds: false, at: start.addingTimeInterval(1000)))
        policy.beginSession(at: start.addingTimeInterval(2000))
        let eligible = start.addingTimeInterval(2180)
        XCTAssertTrue(policy.allowsInterstitial(completedLevels: 4, betweenLevels: true, removesAds: false, at: eligible))
        XCTAssertFalse(policy.allowsInterstitial(completedLevels: 3, betweenLevels: true, removesAds: false, at: eligible))
        XCTAssertFalse(policy.allowsInterstitial(completedLevels: 4, betweenLevels: false, removesAds: false, at: eligible))
        XCTAssertFalse(policy.allowsInterstitial(completedLevels: 4, betweenLevels: true, removesAds: true, at: eligible))
        policy.recordPresentation(interstitial: false, at: eligible)
        XCTAssertFalse(policy.allowsInterstitial(completedLevels: 4, betweenLevels: true, removesAds: false, at: eligible.addingTimeInterval(179)))
        let later = eligible.addingTimeInterval(180)
        XCTAssertTrue(policy.allowsInterstitial(completedLevels: 4, betweenLevels: true, removesAds: false, at: later))
        policy.recordPresentation(interstitial: true, at: later)
        policy.recordPresentation(interstitial: true, at: later.addingTimeInterval(180))
        XCTAssertFalse(policy.allowsInterstitial(completedLevels: 100, betweenLevels: true, removesAds: false, at: later.addingTimeInterval(1000)))
        for index in 0..<5 { policy.recordPresentation(interstitial: false, at: later.addingTimeInterval(Double(400 + index * 30))) }
        XCTAssertFalse(policy.allowsRewarded(at: later.addingTimeInterval(2000)))
        XCTAssertFalse(policy.allowsRewarded(at: start)) // Clock rollback cannot bypass cooldown.
    }
    func testFrequencyAndRewardsSurviveRestartAndV4Migration() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ProgressStore(url: directory.appending(path: "save.json"))
        var progress = PlayerProgress()
        try progress.fulfillPurchase(id: "Xcode.paid", item: .coins, revoked: false)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as? [String: Any])
        old.removeValue(forKey: "adRewardState")
        let v4 = try JSONSerialization.data(withJSONObject: ["version": 4, "progress": old])
        try v4.write(to: store.url)
        progress = try store.load()
        XCTAssertEqual(progress.coins, 1000); XCTAssertTrue(progress.hasAdRewardJournal)
        let ticket = UUID().uuidString
        try progress.claimAdReward(id: ticket, reward: .hint)
        try store.save(progress)
        XCTAssertEqual(try Data(contentsOf: store.url.appendingPathExtension("v4.backup")), v4)
        progress = try store.load()
        XCTAssertFalse(try progress.claimAdReward(id: ticket, reward: .hint))
        XCTAssertEqual(progress.availableHints, 1); XCTAssertEqual(progress.coins, 1000)
        var policy = AdFrequencyManager(); let now = Date()
        policy.beginSession(at: now); policy.recordPresentation(interstitial: true, at: now)
        let restored = try JSONDecoder().decode(AdFrequencyManager.self, from: JSONEncoder().encode(policy))
        XCTAssertEqual(restored, policy)
        let missing = try JSONSerialization.data(withJSONObject: ["version": 5, "progress": old])
        try missing.write(to: store.url); XCTAssertThrowsError(try store.load())
    }
}
