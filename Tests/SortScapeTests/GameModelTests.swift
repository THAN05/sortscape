import XCTest
import SpriteKit
import PuzzleCore
@testable import SortScape

@MainActor
final class GameModelTests: XCTestCase {
    private func model() throws -> GameModel { GameModel(level: try LevelManager.bundled().levels[0]) }
    private func settle() async throws { try await Task.sleep(for: .milliseconds(550)) }

    func testRapidTapsAndCommandsCannotCorruptAnimatingMove() async throws {
        let model = try model()
        model.select(0); model.select(2)
        XCTAssertTrue(model.busy)
        model.select(1); model.select(0); model.undo(); model.restart()
        XCTAssertEqual(model.session.moveCount, 1)
        XCTAssertEqual(model.session.state.containers[2], [.ocean])
        try await settle()
        XCTAssertFalse(model.busy)
        model.undo()
        XCTAssertEqual(model.session.state, model.session.initialState)
        model.select(0); model.select(2)
        try await settle()
        model.restart()
        XCTAssertEqual(model.session.state, model.session.initialState)
        XCTAssertEqual(model.session.moveCount, 0)
        model.leave()
    }

    func testPauseSettlesAnimationAndResumePreservesBoard() async throws {
        let model = try model()
        model.select(0); model.select(2); model.pause()
        XCTAssertFalse(model.busy); XCTAssertTrue(model.paused); XCTAssertTrue(model.scene.isPaused)
        let saved = model.session.state
        model.select(1); model.select(0)
        XCTAssertEqual(model.session.state, saved)
        try await settle()
        model.resume(); XCTAssertFalse(model.scene.isPaused)
        XCTAssertEqual(model.session.state, saved)
        model.undo(); XCTAssertEqual(model.session.state, model.session.initialState)
        model.leave()
    }

    func testRewardedRewindPreservesNormalUndoAndNeverSpendsOnInvalidState() async throws {
        let model = try model(); model.reduceMotion = true
        var spends = 0
        model.rewind { spends += 1; return true }; XCTAssertEqual(spends, 0)
        for (source, destination) in [(0, 2), (1, 0)] {
            model.select(source); model.select(destination)
            try await Task.sleep(for: .milliseconds(30))
        }
        model.rewind { false }; XCTAssertEqual(model.session.moveCount, 2)
        model.rewind { spends += 1; return true }
        XCTAssertEqual(spends, 1); XCTAssertEqual(model.session.moveCount, 0)
        model.select(0); model.select(2)
        try await Task.sleep(for: .milliseconds(30))
        model.undo(); XCTAssertEqual(model.session.moveCount, 0); XCTAssertEqual(spends, 1)
        model.leave()
    }
    func testInvalidMoveLeavesHistoryAndSelectionIntact() throws {
        let model = try model()
        model.select(0); model.select(1)
        XCTAssertEqual(model.session.moveCount, 0)
        XCTAssertEqual(model.selected, 0)
        XCTAssertFalse(model.busy)
        XCTAssertEqual(model.session.state, model.session.initialState)
        model.select(-1); model.select(99)
        XCTAssertEqual(model.session.state, model.session.initialState)
        model.leave()
    }

    func testReducedMotionAndCompletionUndoRestart() async throws {
        let model = try model(); model.reduceMotion = true
        for (source, destination) in [(0,2), (1,0), (2,1)] {
            model.select(source); model.select(destination)
            try await Task.sleep(for: .milliseconds(30))
            XCTAssertFalse(model.busy)
        }
        XCTAssertTrue(model.session.state.isSolved); XCTAssertTrue(model.completionReady)
        model.undo(); XCTAssertFalse(model.completionReady); XCTAssertFalse(model.session.state.isSolved)
        model.restart(); XCTAssertEqual(model.session.state, model.session.initialState)
        XCTAssertEqual(model.session.moveCount, 0)
        model.leave()
    }

    func testHintSelectsLegalSourceWithoutMovingPieces() async throws {
        let model = try model(); let before = model.session.state
        model.hint()
        for _ in 0..<100 where model.findingHint { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(model.findingHint)
        XCTAssertNotNil(model.selected)
        XCTAssertEqual(model.session.state, before)
        XCTAssertEqual(model.session.moveCount, 0)
        XCTAssertTrue(model.message.hasPrefix("Try vessel"))
        model.leave()
    }

    func testPaidAssistChargesOnlyForAValidCurrentMove() async throws {
        let model = try model(); model.reduceMotion = true
        var charges = 0
        model.hint(applyMove: { charges += 1; return true }); model.pause()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(charges, 0); XCTAssertEqual(model.session.moveCount, 0)
        model.resume(); model.hint(applyMove: { false })
        for _ in 0..<100 where model.findingHint { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(model.session.moveCount, 0)
        model.hint(applyMove: { charges += 1; return true })
        for _ in 0..<100 where model.findingHint { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(charges, 1); XCTAssertEqual(model.session.moveCount, 1)
        try await Task.sleep(for: .milliseconds(30))
        model.undo(); XCTAssertEqual(model.session.moveCount, 0); XCTAssertEqual(charges, 1)
        model.leave()
    }
    func testPausedHintCannotApplyStaleResult() async throws {
        let model = try model(); model.hint(); model.pause()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(model.findingHint); XCTAssertNil(model.selected)
        XCTAssertEqual(model.session.moveCount, 0)
        model.leave()
    }
}

extension GameModelTests {
    func testRepresentativeTierBoardsAnimateCompleteUndoAndRestart() async throws {
        let levels = try LevelManager.bundled().levels
        for id in [1, 21, 41, 66, 86, 100] {
            let level = levels[id - 1], model = GameModel(level: levels[id - 1])
            model.scene.size = CGSize(width: 335, height: 280)
            guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { return XCTFail("No solution") }
            for (index, move) in moves.enumerated() {
                model.select(move.source); model.select(move.destination)
                if index == 0 {
                    XCTAssertTrue(model.busy)
                    try await Task.sleep(for: .milliseconds(550))
                    model.reduceMotion = true
                } else { try await Task.sleep(for: .milliseconds(20)) }
                XCTAssertFalse(model.busy)
            }
            XCTAssertTrue(model.session.state.isSolved, "World \(id)")
            XCTAssertTrue(model.completionReady)
            XCTAssertEqual(model.session.moveCount, moves.count)
            for tube in level.state.containers.indices { XCTAssertNotNil(model.scene.childNode(withName: "tube-\(tube)")) }
            for label in model.scene.children.compactMap({ $0 as? SKLabelNode }) {
                XCTAssertGreaterThanOrEqual(label.frame.minY, 0, "World \(id) label should not be clipped")
            }
            model.undo(); XCTAssertFalse(model.session.state.isSolved)
            model.restart(); XCTAssertEqual(model.session.state, level.state)
            XCTAssertEqual(model.session.moveCount, 0)
            model.leave()
        }
    }
}
