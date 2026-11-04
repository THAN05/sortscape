import Foundation

public struct LevelValidation: Codable, Sendable {
    public let id: Int
    public let seed: UInt64
    public let tier: DifficultyTier
    public let solutionLength: Int
    public let solverEffort: Int
    public let difficultyScore: Int
}

public enum CampaignValidator {
    /// Full offline validation: schema/identity/recipe checks are performed by LevelManager;
    /// this independently solves every board and replays every returned move.
    public static func validate(_ manager: LevelManager) throws -> [LevelValidation] {
        guard manager.campaignVersion == 2, manager.levels.count == 100 else { throw LevelError.invalidCatalog }
        return try manager.levels.map { level in
            let analysis = PuzzleSolver().analyze(level.state)
            guard case .solved(let moves) = analysis.result, let metrics = level.metrics, let recipe = level.recipe,
                  moves.count == metrics.solutionLength, analysis.exploredStates == metrics.solverEffort else { throw LevelError.validationFailed(level.id) }
            var replay = level.state
            for move in moves {
                guard replay.move(from: move.source, to: move.destination) else { throw LevelError.validationFailed(level.id) }
            }
            guard replay.isSolved else { throw LevelError.validationFailed(level.id) }
            return LevelValidation(id: level.id, seed: recipe.seed, tier: level.tier, solutionLength: moves.count, solverEffort: analysis.exploredStates, difficultyScore: metrics.score)
        }
    }
}
