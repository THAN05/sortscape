import XCTest
@testable import PuzzleCore

final class PuzzleRulesTests: XCTestCase {
    func testMovesOneTopPieceToEmptyOrMatchingContainer() {
        var state = PuzzleState(containers: [[.coral, .ocean], [.ocean], []])
        XCTAssertTrue(state.move(from: 0, to: 1))
        XCTAssertEqual(state.containers, [[.coral], [.ocean, .ocean], []])
        XCTAssertTrue(state.move(from: 0, to: 2))
        XCTAssertEqual(state.containers[2], [.coral])
    }

    func testIllegalMovesDoNotMutateState() {
        let original = PuzzleState(containers: [[.coral], [.ocean], [], [.coral, .coral, .coral, .coral]])
        for (source, destination) in [(0,0), (0,1), (2,0), (0,3), (-1,0), (0,4)] {
            var state = original
            XCTAssertFalse(state.move(from: source, to: destination))
            XCTAssertEqual(state, original)
        }
    }

    func testOnlyFullUniformContainersCountAsSolved() {
        XCTAssertTrue(PuzzleState(containers: [[.coral, .coral, .coral, .coral], []]).isSolved)
        XCTAssertFalse(PuzzleState(containers: [[.coral], []]).isSolved)
        XCTAssertFalse(PuzzleState(containers: [[.coral, .coral, .coral, .ocean], []]).isSolved)
    }

    func testUndoAndRestartRestoreExactStateAndMoveCount() {
        let original = try! LevelManager.bundled().levels[0].state
        var session = PuzzleSession(state: original)
        session.undo()
        XCTAssertFalse(session.move(from: 0, to: 1))
        XCTAssertFalse(session.canUndo)
        XCTAssertTrue(session.move(from: 0, to: 2))
        let afterFirst = session.state
        XCTAssertTrue(session.move(from: 1, to: 0))
        XCTAssertEqual(session.moveCount, 2)
        session.undo()
        XCTAssertEqual(session.state, afterFirst)
        XCTAssertEqual(session.moveCount, 1)
        session.restart()
        XCTAssertEqual(session.state, original)
        XCTAssertEqual(session.moveCount, 0)
        XCTAssertFalse(session.canUndo)
    }

    func testAllHundredBundledLevelsHaveLegalSolutions() throws {
        let manager = try LevelManager.bundled()
        XCTAssertEqual(manager.levels.count, 100)
        for level in manager.levels {
            guard case .solved(let moves) = PuzzleSolver().solve(level.state) else {
                XCTFail("Level \(level.id) must be solvable"); continue
            }
            var state = level.state
            for move in moves { XCTAssertTrue(state.move(from: move.source, to: move.destination)) }
            XCTAssertTrue(state.isSolved, "Level \(level.id)")
        }
    }
}
