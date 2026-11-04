import Foundation
import XCTest
@testable import PuzzleCore

final class CampaignProgressTests: XCTestCase {
    private func session(_ level: Level) throws -> PuzzleSession {
        guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { throw LevelError.validationFailed(level.id) }
        var session = PuzzleSession(state: level.state)
        for move in moves { XCTAssertTrue(session.move(from: move.source, to: move.destination)) }
        return session
    }
    func testFullCampaignUnlocksAndAwardsEachLevelExactlyOnce() throws {
        var progress = PlayerProgress()
        let levels = try LevelManager.bundled().levels
        XCTAssertFalse(progress.isUnlocked(0)); XCTAssertFalse(progress.isUnlocked(101))
        for level in levels {
            XCTAssertTrue(progress.isUnlocked(level.id))
            if level.id < 100 { XCTAssertFalse(progress.isUnlocked(level.id + 1)) }
            let solved = try session(level)
            XCTAssertEqual(progress.complete(level: level, session: solved), 35 + MilestoneRewards.levels[level.id, default: 0] + MilestoneRewards.restorationFunding[level.id, default: 0])
            XCTAssertEqual(progress.complete(level: level, session: solved), 0)
            XCTAssertEqual(progress.stars[level.id], 3)
        }
        XCTAssertEqual(progress.bestMoves.count, 100); XCTAssertEqual(progress.coins, 30_990)
        XCTAssertEqual(progress.totalStars, 300); XCTAssertFalse(progress.isUnlocked(101))
    }
    func testReplayImprovesStarsAndBestMovesWithoutDuplicateReward() throws {
        let level = try LevelManager.bundled().levels[0]
        func solve(extraLoops: Int) -> PuzzleSession {
            var session = PuzzleSession(state: level.state)
            session.move(from: 0, to: 2); session.move(from: 1, to: 0)
            for _ in 0..<extraLoops { session.move(from: 1, to: 2); session.move(from: 2, to: 1) }
            session.move(from: 2, to: 1); return session
        }
        var progress = PlayerProgress()
        XCTAssertEqual(progress.complete(level: level, session: solve(extraLoops: 2)), 25)
        XCTAssertEqual(progress.stars[1], 1)
        XCTAssertEqual(progress.complete(level: level, session: solve(extraLoops: 1)), 5)
        XCTAssertEqual(progress.stars[1], 2)
        XCTAssertEqual(progress.complete(level: level, session: solve(extraLoops: 0)), 5)
        XCTAssertEqual(progress.stars[1], 3); XCTAssertEqual(progress.bestMoves[1], 3)
        progress.complete(level: level, session: solve(extraLoops: 2))
        XCTAssertEqual(progress.stars[1], 3); XCTAssertEqual(progress.bestMoves[1], 3); XCTAssertEqual(progress.coins, 35)
    }
    func testVersionOneMigrationPreservesCoinsScoresAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("progress.json"))
        var old: [Int: Int] = [:]
        for level in try LevelManager.legacyBundled().levels { old[level.id] = try session(level).moveCount }
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "progress": ["bestMoves": Dictionary(uniqueKeysWithValues: old.map { (String($0.key), $0.value) })]])
        try data.write(to: store.url)
        let migrated = try store.load()
        XCTAssertEqual(migrated.coins, 375); XCTAssertEqual(migrated.legacyBestMoves, old)
        XCTAssertTrue((1...16).allSatisfy(migrated.isUnlocked))
        XCTAssertEqual(migrated.bestMoves[1], old[1]); XCTAssertEqual(migrated.bestMoves[2], old[2])
        XCTAssertEqual(try Data(contentsOf: store.url), data)
        var replayed = migrated
        let first = try LevelManager.bundled().levels[0]
        XCTAssertEqual(replayed.complete(level: first, session: try session(first)), 0)
        try store.save(replayed)
        XCTAssertEqual(try Data(contentsOf: store.url.appendingPathExtension("v1.backup")), data)
        XCTAssertEqual(try store.load(), replayed)
    }
    func testStarsAndUnlocksPersistAcrossFreshStoreInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("progress.json")
        var progress = PlayerProgress()
        let level = try LevelManager.bundled().levels[0]
        progress.complete(level: level, session: try session(level))
        try ProgressStore(url: url).save(progress)
        let restored = try ProgressStore(url: url).load()
        XCTAssertEqual(restored.stars[1], 3); XCTAssertTrue(restored.isUnlocked(2))
        XCTAssertFalse(restored.isUnlocked(3)); XCTAssertEqual(restored.coins, 35)
    }
}
