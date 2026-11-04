import Foundation

public enum DifficultyTier: String, Codable, CaseIterable, Sendable {
    case beginner, easy, medium, hard, expert
    public var title: String { rawValue.capitalized }
    public var range: ClosedRange<Int> {
        switch self {
        case .beginner: 1...20
        case .easy: 21...40
        case .medium: 41...65
        case .hard: 66...85
        case .expert: 86...100
        }
    }
    public static func forLevel(_ id: Int) -> DifficultyTier { allCases.first { $0.range.contains(id) } ?? .expert }
    public var guidance: String {
        switch self {
        case .beginner: "Move one top piece onto its matching color or an empty vessel. Four matching pieces restore a vessel."
        case .easy: "Plan a few moves ahead. Keep an empty vessel available when you can."
        case .medium: "More mixed colors mean more choices. Look for pieces that free a matching color underneath."
        case .hard: "Space becomes precious. Think about where each exposed color can go before moving it."
        case .expert: "Use every vessel carefully. Undo is always available. Each level has one hint. There is no timer."
        }
    }
}

public struct GenerationRecipe: Codable, Equatable, Sendable {
    public let version: Int
    public let seed: UInt64
    public let colors: Int
    public let emptyContainers: Int
    public init(version: Int = 1, seed: UInt64, colors: Int, emptyContainers: Int) {
        self.version = version; self.seed = seed; self.colors = colors; self.emptyContainers = emptyContainers
    }
}

/// SplitMix64 and Fisher–Yates are specified here rather than using platform RNGs.
public struct SeededLevelGenerator: Sendable {
    public init() {}
    public func generate(_ recipe: GenerationRecipe) throws -> PuzzleState {
        if recipe.version == 0 {
            let legacy = try LevelManager.legacyBundled()
            guard recipe.seed >= 1, recipe.seed <= UInt64(legacy.levels.count) else { throw LevelError.invalidCatalog }
            let state = legacy.levels[Int(recipe.seed) - 1].state
            guard Set(state.containers.flatMap { $0 }).count == recipe.colors,
                  state.containers.filter(\.isEmpty).count == recipe.emptyContainers else { throw LevelError.invalidCatalog }
            return state
        }
        guard recipe.version == 1, (2...4).contains(recipe.colors), (1...2).contains(recipe.emptyContainers) else { throw LevelError.invalidCatalog }
        var seed = recipe.seed
        func next(_ upper: Int) -> Int {
            seed &+= 0x9E3779B97F4A7C15
            var value = seed
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            value ^= value >> 31
            return Int(value % UInt64(upper))
        }
        var pieces = (0..<recipe.colors).flatMap { Array(repeating: PieceColor(rawValue: $0)!, count: 4) }
        for index in stride(from: pieces.count - 1, through: 1, by: -1) { pieces.swapAt(index, next(index + 1)) }
        var tubes = (0..<recipe.colors).map { Array(pieces[($0 * 4)..<($0 * 4 + 4)]) }
        tubes += Array(repeating: [], count: recipe.emptyContainers)
        return PuzzleState(containers: tubes)
    }
}

public struct DifficultyMetrics: Codable, Equatable, Sendable {
    public let solutionLength: Int
    public let solverEffort: Int
    public let complexity: Int
    public let score: Int
    public init(state: PuzzleState, solutionLength: Int, solverEffort: Int) {
        let boundaries = state.containers.reduce(0) { count, tube in count + zip(tube, tube.dropFirst()).filter { $0 != $1 }.count }
        let colors = Set(state.containers.flatMap { $0 }).count
        let empties = state.containers.filter(\.isEmpty).count
        complexity = boundaries * 2 + colors * 4 + (empties == 1 ? 6 : 0)
        self.solutionLength = solutionLength; self.solverEffort = solverEffort
        score = solutionLength * 3 + complexity + Int(log2(Double(solverEffort + 1)))
    }
}

/// Board identity ignores both tube order and color names; cosmetic permutations aren't new puzzles.
public enum BoardIdentity {
    public static func canonical(_ state: PuzzleState) -> String {
        let colors = Array(Set(state.containers.flatMap { $0 })).sorted { $0.rawValue < $1.rawValue }
        func permutations(_ values: [Int]) -> [[Int]] {
            if values.isEmpty { return [[]] }
            return values.flatMap { first in permutations(values.filter { $0 != first }).map { [first] + $0 } }
        }
        return permutations(Array(0..<colors.count)).map { permutation in
            let map = Dictionary(uniqueKeysWithValues: zip(colors, permutation))
            return state.containers.map { tube in tube.map { String(map[$0]!) }.joined() }.sorted().joined(separator: ":")
        }.min() ?? ""
    }
}
