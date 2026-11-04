import Foundation
import XCTest
@testable import PuzzleCore

final class CampaignTests: XCTestCase {
    func testAllHundredLevelsValidateAndReproduceExactly() throws {
        let manager = try LevelManager.bundled()
        let report = try CampaignValidator.validate(manager)
        XCTAssertEqual(report.count, 100)
        XCTAssertEqual(Set(manager.levels.map { BoardIdentity.canonical($0.state) }).count, 100)
        for level in manager.levels {
            let recipe = try XCTUnwrap(level.recipe)
            XCTAssertEqual(try SeededLevelGenerator().generate(recipe), level.state)
            XCTAssertEqual(try SeededLevelGenerator().generate(recipe), try SeededLevelGenerator().generate(recipe))
        }
    }
    func testTierCountsAndDifficultyCurveHaveNoSpikes() throws {
        let levels = try LevelManager.bundled().levels
        XCTAssertEqual(DifficultyTier.allCases.map { tier in levels.filter { $0.tier == tier }.count }, [20,20,25,20,15])
        for (left, right) in zip(levels, levels.dropFirst()) {
            let previous = try XCTUnwrap(left.metrics), current = try XCTUnwrap(right.metrics)
            XCTAssertGreaterThanOrEqual(current.score, previous.score)
            XCTAssertLessThanOrEqual(current.score - previous.score, 12)
        }
        XCTAssertLessThan(try XCTUnwrap(levels[19].metrics).score, try XCTUnwrap(levels[85].metrics).score)
    }
    func testCanonicalIdentityRejectsCosmeticPermutations() {
        let a = PuzzleState(containers: [[.coral,.coral,.coral,.ocean],[.ocean,.ocean,.ocean,.coral], []])
        let b = PuzzleState(containers: [[], [.mint,.mint,.mint,.gold],[.gold,.gold,.gold,.mint]])
        XCTAssertEqual(BoardIdentity.canonical(a), BoardIdentity.canonical(b))
        let c = PuzzleState(containers: [[.coral,.coral,.ocean,.ocean],[.ocean,.ocean,.coral,.coral], []])
        XCTAssertNotEqual(BoardIdentity.canonical(a), BoardIdentity.canonical(c))
    }
    func testGeneratorRejectsUnsupportedRecipesAndHugeLegacySeed() {
        for recipe in [GenerationRecipe(seed: 1, colors: 1, emptyContainers: 2), GenerationRecipe(seed: 1, colors: 5, emptyContainers: 2), GenerationRecipe(seed: 1, colors: 4, emptyContainers: 3), GenerationRecipe(version: 9, seed: 1, colors: 3, emptyContainers: 1), GenerationRecipe(version: 0, seed: UInt64.max, colors: 2, emptyContainers: 1)] {
            XCTAssertThrowsError(try SeededLevelGenerator().generate(recipe))
        }
    }
    func testStrictSchemaAndTamperedCampaignAreRejected() throws {
        let levels = try LevelManager.bundled().levels
        let original = CampaignFile(levels: levels.map { LevelDefinition(id: $0.id, name: $0.name, state: $0.state, recipe: $0.recipe!, metrics: $0.metrics!) })
        let data = try JSONEncoder().encode(original)
        func mutate(_ change: (inout [String: Any]) -> Void) throws -> Data {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); change(&json)
            return try JSONSerialization.data(withJSONObject: json)
        }
        for damaged in try [
            mutate { $0["unexpected"] = true }, mutate { $0["schemaVersion"] = 99 },
            mutate { var rows = $0["levels"] as! [[String: Any]]; rows[1]["id"] = 1; $0["levels"] = rows },
            mutate { var rows = $0["levels"] as! [[String: Any]]; rows[20]["tier"] = "expert"; $0["levels"] = rows },
            mutate { var rows = $0["levels"] as! [[String: Any]]; rows[3]["containers"] = rows[2]["containers"]; rows[3]["recipe"] = rows[2]["recipe"]; rows[3]["metrics"] = rows[2]["metrics"]; $0["levels"] = rows },
            mutate { var rows = $0["levels"] as! [[String: Any]]; rows[99]["containers"] = [[0,0,0,0,0],[],[]]; $0["levels"] = rows }
        ] { XCTAssertThrowsError(try LevelManager(data: damaged)) }
        let fakeSolution = try mutate {
            var rows = $0["levels"] as! [[String: Any]], metrics = rows[99]["metrics"] as! [String: Int]
            metrics["solutionLength"]! += 1; metrics["score"]! += 3; rows[99]["metrics"] = metrics; $0["levels"] = rows
        }
        let manager = try LevelManager(data: fakeSolution)
        XCTAssertThrowsError(try CampaignValidator.validate(manager))
    }
    func testAStarMatchesIndependentBreadthFirstSearchOnSmallBoards() throws {
        let levels = try LevelManager.bundled().levels.filter { Set($0.state.containers.flatMap { $0 }).count == 2 }.prefix(6)
        for level in levels {
            var queue = [(level.state, 0)], visited: Set<PuzzleState> = [level.state], cursor = 0, optimal: Int?
            while cursor < queue.count {
                let (state, distance) = queue[cursor]; cursor += 1
                if state.isSolved { optimal = distance; break }
                for source in state.containers.indices {
                    for destination in state.containers.indices {
                        var next = state
                        if next.move(from: source, to: destination), visited.insert(next).inserted { queue.append((next, distance + 1)) }
                    }
                }
            }
            guard case .solved(let moves) = PuzzleSolver().solve(level.state) else { return XCTFail("Solver failed") }
            XCTAssertEqual(moves.count, optimal)
        }
    }
}
