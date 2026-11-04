import Foundation

public struct Level: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let state: PuzzleState
    public let recipe: GenerationRecipe?
    public let metrics: DifficultyMetrics?
    public var tier: DifficultyTier { .forLevel(id) }
    public func stars(for moves: Int) -> Int {
        guard moves > 0 else { return 0 }
        guard let target = metrics?.solutionLength else { return 1 }
        if moves <= target + max(1, target / 5) { return 3 }
        if moves <= target + max(3, target / 2) { return 2 }
        return 1
    }
    init(id: Int, name: String, state: PuzzleState, recipe: GenerationRecipe? = nil, metrics: DifficultyMetrics? = nil) {
        self.id = id; self.name = name; self.state = state; self.recipe = recipe; self.metrics = metrics
    }
}

public struct LevelDefinition: Codable, Sendable {
    public let id: Int
    public let name: String
    public let tier: DifficultyTier
    public let containers: [[PieceColor]]
    public let recipe: GenerationRecipe
    public let metrics: DifficultyMetrics
    public init(id: Int, name: String, state: PuzzleState, recipe: GenerationRecipe, metrics: DifficultyMetrics) {
        self.id = id; self.name = name; tier = .forLevel(id); containers = state.containers; self.recipe = recipe; self.metrics = metrics
    }
}
public struct CampaignFile: Codable, Sendable {
    public let schemaVersion: Int
    public let generatorVersion: Int
    public let levels: [LevelDefinition]
    public init(levels: [LevelDefinition]) { schemaVersion = 2; generatorVersion = 1; self.levels = levels }
}
public enum LevelError: Error, Equatable {
    case missingResource, invalidCatalog, invalidLevel(Int), duplicateLevel(Int), validationFailed(Int)
}

public struct LevelManager: Sendable {
    public let levels: [Level]
    public let campaignVersion: Int
    private struct Record: Decodable { let id: Int; let name: String; let containers: [[PieceColor]] }

    private static func state(id: Int, name: String, containers: [[PieceColor]]) throws -> PuzzleState {
        let pieces = containers.flatMap { $0 }
        let counts = Dictionary(grouping: pieces, by: { $0 }).mapValues(\.count)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (3...6).contains(containers.count), containers.allSatisfy({ $0.count <= 4 }),
              !pieces.isEmpty, counts.values.allSatisfy({ $0 == 4 }), containers.contains(where: \.isEmpty) else { throw LevelError.invalidLevel(id) }
        let state = PuzzleState(containers: containers)
        guard !state.isSolved else { throw LevelError.invalidLevel(id) }
        return state
    }
    public init(data: Data) throws {
        let decoder = JSONDecoder()
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard Set(object.keys) == ["schemaVersion", "generatorVersion", "levels"],
                  let rows = object["levels"] as? [[String: Any]] else { throw LevelError.invalidCatalog }
            for row in rows {
                guard Set(row.keys) == ["id", "name", "tier", "containers", "recipe", "metrics"],
                      let recipe = row["recipe"] as? [String: Any], Set(recipe.keys) == ["version", "seed", "colors", "emptyContainers"],
                      let metrics = row["metrics"] as? [String: Any], Set(metrics.keys) == ["solutionLength", "solverEffort", "complexity", "score"] else { throw LevelError.invalidCatalog }
            }
            let campaign = try decoder.decode(CampaignFile.self, from: data)
            guard campaign.schemaVersion == 2, campaign.generatorVersion == 1,
                  campaign.levels.count == 100, campaign.levels.map(\.id) == Array(1...100) else { throw LevelError.invalidCatalog }
            var identities = Set<String>()
            var previousScore = 0
            levels = try campaign.levels.map { record in
                let state = try Self.state(id: record.id, name: record.name, containers: record.containers)
                guard record.tier == .forLevel(record.id), (1...128).contains(record.metrics.solutionLength),
                      (1...200_000).contains(record.metrics.solverEffort),
                      record.metrics == DifficultyMetrics(state: state, solutionLength: record.metrics.solutionLength, solverEffort: record.metrics.solverEffort),
                      record.metrics.score >= previousScore,
                      previousScore == 0 || record.metrics.score - previousScore <= 12,
                      try SeededLevelGenerator().generate(record.recipe) == state else { throw LevelError.invalidLevel(record.id) }
                guard identities.insert(BoardIdentity.canonical(state)).inserted else { throw LevelError.duplicateLevel(record.id) }
                previousScore = record.metrics.score
                return Level(id: record.id, name: record.name, state: state, recipe: record.recipe, metrics: record.metrics)
            }
            campaignVersion = 2
        } else {
            let records = try decoder.decode([Record].self, from: data)
            guard !records.isEmpty, records.map(\.id) == Array(1...records.count) else { throw LevelError.invalidCatalog }
            levels = try records.map { Level(id: $0.id, name: $0.name, state: try Self.state(id: $0.id, name: $0.name, containers: $0.containers)) }
            campaignVersion = 1
        }
    }
    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle(for: ResourceAnchor.self)
        #endif
    }
    public static func bundled() throws -> LevelManager {
        guard let url = resourceBundle.url(forResource: "campaign", withExtension: "json") else { throw LevelError.missingResource }
        return try LevelManager(data: Data(contentsOf: url))
    }
    public static func legacyBundled() throws -> LevelManager {
        guard let url = resourceBundle.url(forResource: "beginner", withExtension: "json") else { throw LevelError.missingResource }
        return try LevelManager(data: Data(contentsOf: url))
    }
    public func next(after id: Int) -> Level? { levels.first { $0.id == id + 1 } }
}
private final class ResourceAnchor {}
