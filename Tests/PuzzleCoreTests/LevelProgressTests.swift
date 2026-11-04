import Foundation
import XCTest
@testable import PuzzleCore

final class LevelProgressTests: XCTestCase {
    func testCatalogRejectsMalformedAndInvalidLevels() throws {
        for json in ["{}", "[]", "[{\"id\":2,\"name\":\"X\",\"containers\":[[0,0,0,1],[1,1,1,0],[]]}]",
                     "[{\"id\":1,\"name\":\"X\",\"containers\":[[0,0,0,0,0],[],[]]}]",
                     "[{\"id\":1,\"name\":\"X\",\"containers\":[[0],[],[]]}]",
                     "[{\"id\":1,\"name\":\"X\",\"containers\":[[9],[],[]]}]",
                     "[{\"id\":1,\"name\":\"X\",\"containers\":[[0,0,0,0],[],[]]}]"] {
            XCTAssertThrowsError(try LevelManager(data: Data(json.utf8)), json)
        }
    }

    func testSolverReportsSolvedUnsolvableAndBudgetExhaustion() {
        XCTAssertEqual(PuzzleSolver().solve(PuzzleState(containers: [[.coral,.coral,.coral,.coral], []])), .solved([]))
        XCTAssertEqual(PuzzleSolver().solve(PuzzleState(containers: [[.coral], [.ocean]])), .unsolvable)
        XCTAssertEqual(PuzzleSolver().solve(PuzzleState(containers: [[.coral], []]), maximumStates: 0), .searchLimitReached)
    }

    func testCompletionUnlocksNextLevelAndRewardsOnlyOnce() throws {
        let manager = try LevelManager.bundled()
        let level = manager.levels[0]
        var progress = PlayerProgress()
        var session = PuzzleSession(state: level.state)
        XCTAssertTrue(progress.isUnlocked(1)); XCTAssertFalse(progress.isUnlocked(2))
        XCTAssertEqual(progress.complete(level: level, session: session), 0)
        guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { return XCTFail("No solution") }
        for move in moves { session.move(from: move.source, to: move.destination) }
        XCTAssertEqual(progress.complete(level: level, session: session), 35)
        XCTAssertEqual(progress.coins, 35)
        XCTAssertEqual(progress.bestMoves[1], moves.count)
        XCTAssertTrue(progress.isUnlocked(2)); XCTAssertFalse(progress.isUnlocked(3))
        XCTAssertEqual(progress.complete(level: level, session: session), 0)
        session.undo()
        XCTAssertEqual(progress.complete(level: level, session: session), 0)
        XCTAssertEqual(progress.coins, 35)
        XCTAssertEqual(manager.next(after: 1)?.id, 2)
        XCTAssertNil(manager.next(after: 100))
    }

    func testProgressRejectsLockedAndMismatchedSessions() throws {
        let levels = try LevelManager.bundled().levels
        var progress = PlayerProgress()
        var session = PuzzleSession(state: levels[1].state)
        guard case .solved(let moves) = PuzzleSolver().solve(session.state) else { return XCTFail("No solution") }
        for move in moves { session.move(from: move.source, to: move.destination) }
        XCTAssertEqual(progress.complete(level: levels[1], session: session), 0)
        XCTAssertEqual(progress.complete(level: levels[0], session: session), 0)
        XCTAssertTrue(progress.bestMoves.isEmpty)
    }

    func testProgressPersistsAndCorruptionIsReported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("progress.json"))
        XCTAssertEqual(try store.load(), PlayerProgress())
        let level = try LevelManager.bundled().levels[0]
        var session = PuzzleSession(state: level.state)
        guard case .solved(let moves) = PuzzleSolver().solve(session.state) else { return XCTFail("No solution") }
        for move in moves { session.move(from: move.source, to: move.destination) }
        var progress = PlayerProgress()
        progress.complete(level: level, session: session)
        try store.save(progress)
        XCTAssertEqual(try ProgressStore(url: store.url).load(), progress)
        try Data("corrupt".utf8).write(to: store.url)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try String(contentsOf: store.url, encoding: .utf8), "corrupt")
    }
}
