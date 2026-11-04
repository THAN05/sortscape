import Foundation
import XCTest
import PuzzleCore
@testable import SortScape

@MainActor final class PuzzleCheckpointTests: XCTestCase {
    private func fixture() throws -> PuzzleCheckpointStore {
        let level = try LevelManager.bundled().levels[0]
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return PuzzleCheckpointStore(url: directory.appending(path: "attempt.json"), level: level)
    }

    func testMoveIsRecoverableBeforeAnimationFinishesAndUndoPersists() throws {
        let store = try fixture()
        XCTAssertNil(try store.load())
        let original = GameModel(level: store.level, checkpoint: store)
        original.select(0); original.select(2)
        XCTAssertTrue(original.busy)
        let restored = GameModel(level: store.level, checkpoint: store)
        XCTAssertEqual(restored.session.state, original.session.state)
        XCTAssertEqual(restored.session.moveCount, 1)
        XCTAssertFalse(restored.busy)
        restored.undo()
        XCTAssertEqual(restored.session.state, store.level.state)
        XCTAssertNil(try store.load())
        original.leave()
    }

    func testSolvedCheckpointCanBeRetriedUntilRewardsAreCommitted() throws {
        let store = try fixture()
        guard case .solved(let moves) = PuzzleSolver().solve(store.level.state) else { return XCTFail("Missing solution") }
        var session = PuzzleSession(state: store.level.state)
        for move in moves { XCTAssertTrue(session.move(from: move.source, to: move.destination)) }
        try store.save(session)
        let recovered = GameModel(level: store.level, checkpoint: store)
        XCTAssertTrue(recovered.completionReady)
        XCTAssertEqual(recovered.session.moveCount, moves.count)
        XCTAssertNotNil(try store.load())
        recovered.clearCompletedCheckpoint()
        XCTAssertNil(try store.load())
    }

    func testInvalidMoveJournalDoesNotReplaceSaveOnRead() throws {
        let store = try fixture()
        var session = PuzzleSession(state: store.level.state)
        XCTAssertTrue(session.move(from: 0, to: 2))
        try store.save(session)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as? [String: Any])
        object["moves"] = [["source": -1, "destination": 2]]
        let corrupt = try JSONSerialization.data(withJSONObject: object)
        try corrupt.write(to: store.url)
        let recovered = GameModel(level: store.level, checkpoint: store)
        XCTAssertEqual(recovered.session.moveCount, 0)
        XCTAssertNotNil(recovered.checkpointError)
        XCTAssertEqual(try Data(contentsOf: store.url), corrupt)
    }
}
