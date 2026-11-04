import Foundation
import PuzzleCore

struct Candidate {
    let state: PuzzleState
    let recipe: GenerationRecipe
    let metrics: DifficultyMetrics
    let name: String?
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let args = CommandLine.arguments
if args.dropFirst().first == "validate" {
    let manager = try LevelManager(data: Data(contentsOf: URL(fileURLWithPath: args.count > 2 ? args[2] : "Sources/PuzzleCore/Resources/campaign.json")))
    let report = try CampaignValidator.validate(manager)
    let path = args.count > 3 ? args[3] : "Documentation/level-validation.json"
    try encoder.encode(report).write(to: URL(fileURLWithPath: path), options: .atomic)
    print("Validated \(report.count)/100 levels, all solutions replayed; report: \(path)")
} else {
    var seen = Set<String>(), candidates: [Candidate] = []
    var rejected = 0
    var duplicates = 0, solved = 0, unsolvable = 0, limited = 0
    func consider(_ recipe: GenerationRecipe, name: String? = nil) throws {
        let state = try SeededLevelGenerator().generate(recipe)
        guard !state.isSolved else { rejected += 1; solved += 1; return }
        let key = BoardIdentity.canonical(state)
        guard !seen.contains(key) else { rejected += 1; duplicates += 1; return }
        let analysis = PuzzleSolver().analyze(state, maximumStates: 30_000)
        guard case .solved(let moves) = analysis.result else {
            rejected += 1
            if case .unsolvable = analysis.result { unsolvable += 1 } else { limited += 1 }
            return
        }
        let metrics = DifficultyMetrics(state: state, solutionLength: moves.count, solverEffort: analysis.exploredStates)
        seen.insert(key); candidates.append(Candidate(state: state, recipe: recipe, metrics: metrics, name: name))
    }
    let legacy = try LevelManager.legacyBundled()
    for level in legacy.levels {
        try consider(GenerationRecipe(version: 0, seed: UInt64(level.id), colors: Set(level.state.containers.flatMap { $0 }).count, emptyContainers: level.state.containers.filter(\.isEmpty).count), name: level.name)
    }
    for (colors, empty, count) in [(2,1,55), (2,2,55), (3,2,100), (3,1,100), (4,2,120), (4,1,120)] {
        for index in 0..<count {
            try consider(GenerationRecipe(seed: UInt64(colors * 1_000_000 + empty * 100_000 + index), colors: colors, emptyContainers: empty))
        }
        print("Pool: colors=\(colors) empties=\(empty), \(candidates.count) unique solvable, \(rejected) rejected")
        fflush(stdout)
    }
    let first = candidates.first { $0.recipe.version == 0 && $0.recipe.seed == 1 }!
    let second = candidates.first { $0.recipe.version == 0 && $0.recipe.seed == 2 }!
    let pool = candidates.filter { $0.metrics.score >= second.metrics.score && $0.recipe != first.recipe && $0.recipe != second.recipe }.sorted {
        if $0.metrics.score != $1.metrics.score { return $0.metrics.score < $1.metrics.score }
        if $0.recipe.version != $1.recipe.version { return $0.recipe.version < $1.recipe.version }
        return $0.recipe.seed < $1.recipe.seed
    }
    guard pool.count >= 98 else { fatalError("Insufficient unique candidates: \(pool.count)") }
    // Evenly sample the measured distribution, then enforce bounded adjacent increases.
    var selected = [first, second]
    for index in 0..<98 { selected.append(pool[index * (pool.count - 1) / 97]) }
    let names = ["Dewdrop", "Willow", "Coral", "Sunlit", "Clover", "Amber", "Bluebell", "Pebble", "Fern", "Jade", "Orchid", "Moss", "Lotus", "Saffron", "Silver", "Rose", "Moonlit", "Iris", "Pearl", "Aurora"]
    let places = ["Meadow", "Cove", "Grove", "Terrace", "Summit"]
    let definitions = selected.enumerated().map { index, candidate in
        LevelDefinition(id: index + 1, name: candidate.name ?? "\(names[index % names.count]) \(places[index / names.count])", state: candidate.state, recipe: candidate.recipe, metrics: candidate.metrics)
    }
    let data = try encoder.encode(CampaignFile(levels: definitions))
    let verified = try LevelManager(data: data)
    let report = try CampaignValidator.validate(verified)
    try data.write(to: URL(fileURLWithPath: "Sources/PuzzleCore/Resources/campaign.json"), options: .atomic)
    try encoder.encode(report).write(to: URL(fileURLWithPath: "Documentation/level-validation.json"), options: .atomic)
    print("Generated \(definitions.count); validated \(report.count); rejected \(rejected): \(duplicates) duplicates, \(solved) pre-solved, \(unsolvable) unsolvable, \(limited) budget-limited.")
}
