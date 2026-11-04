public struct PuzzleMove: Equatable, Sendable, Codable {
    public let source: Int
    public let destination: Int
}

public enum SolverResult: Equatable, Sendable {
    case solved([PuzzleMove])
    case unsolvable
    case searchLimitReached
}

public struct SolverAnalysis: Sendable {
    public let result: SolverResult
    public let exploredStates: Int
}

/// A* with an admissible bound: all pieces outside the longest uniform bottom run
/// for their color must move at least once. Tube permutations are equivalent states.
public struct PuzzleSolver: Sendable {
    public init() {}
    public func solve(_ initial: PuzzleState, maximumStates: Int = 200_000) -> SolverResult {
        analyze(initial, maximumStates: maximumStates).result
    }
    public func analyze(_ initial: PuzzleState, maximumStates: Int = 200_000) -> SolverAnalysis {
        struct Entry { let state: PuzzleState; let parent: Int?; let move: PuzzleMove?; let cost: Int; let bound: Int }
        struct Item { let index: Int; let total: Int; let bound: Int }
        func precedes(_ a: Item, _ b: Item) -> Bool {
            if a.total != b.total { return a.total < b.total }
            if a.bound != b.bound { return a.bound < b.bound }
            return a.index < b.index
        }
        var heap: [Item] = []
        func push(_ item: Item) {
            heap.append(item); var index = heap.count - 1
            while index > 0 {
                let parent = (index - 1) / 2
                guard precedes(heap[index], heap[parent]) else { break }
                heap.swapAt(index, parent); index = parent
            }
        }
        func pop() -> Item? {
            guard !heap.isEmpty else { return nil }
            if heap.count == 1 { return heap.removeLast() }
            let result = heap[0]; heap[0] = heap.removeLast(); var index = 0
            while index * 2 + 1 < heap.count {
                var child = index * 2 + 1
                if child + 1 < heap.count && precedes(heap[child + 1], heap[child]) { child += 1 }
                guard precedes(heap[child], heap[index]) else { break }
                heap.swapAt(child, index); index = child
            }
            return result
        }
        func key(_ state: PuzzleState) -> [UInt16] {
            state.containers.map { $0.reduce(UInt16(1)) { $0 * 5 + UInt16($1.rawValue + 1) } }.sorted()
        }
        func bound(_ state: PuzzleState) -> Int {
            var longest = [Int](repeating: 0, count: PieceColor.allCases.count)
            for tube in state.containers {
                guard let color = tube.first else { continue }
                longest[color.rawValue] = max(longest[color.rawValue], tube.prefix(while: { $0 == color }).count)
            }
            return state.containers.flatMap { $0 }.count - longest.reduce(0, +)
        }
        if initial.isSolved { return SolverAnalysis(result: .solved([]), exploredStates: 0) }
        guard maximumStates > 0 else { return SolverAnalysis(result: .searchLimitReached, exploredStates: 0) }
        var entries = [Entry(state: initial, parent: nil, move: nil, cost: 0, bound: bound(initial))]
        var best = [key(initial): 0]
        var explored = 0
        push(Item(index: 0, total: entries[0].bound, bound: entries[0].bound))
        while let item = pop() {
            if Task.isCancelled { return SolverAnalysis(result: .searchLimitReached, exploredStates: explored) }
            let entry = entries[item.index], state = entry.state
            guard best[key(state)] == entry.cost else { continue }
            if state.isSolved {
                var path: [PuzzleMove] = [], cursor = item.index
                while let parent = entries[cursor].parent, let move = entries[cursor].move {
                    path.append(move); cursor = parent
                }
                return SolverAnalysis(result: .solved(path.reversed()), exploredStates: explored)
            }
            guard explored < maximumStates, entries.count / 8 < maximumStates else {
                return SolverAnalysis(result: .searchLimitReached, exploredStates: explored)
            }
            explored += 1
            for source in state.containers.indices {
                let pieces = state.containers[source]
                if pieces.count == 4 && Set(pieces).count == 1 { continue }
                var triedEmpty = false
                for destination in state.containers.indices {
                    guard state.canMove(from: source, to: destination) else { continue }
                    if state.containers[destination].isEmpty {
                        // Relocating a uniform stack to another empty tube adds no useful state.
                        if Set(pieces).count == 1 || triedEmpty { continue }
                        triedEmpty = true
                    }
                    var next = state; next.move(from: source, to: destination)
                    let cost = entry.cost + 1, nextKey = key(next)
                    guard cost < best[nextKey, default: Int.max] else { continue }
                    best[nextKey] = cost
                    let heuristic = bound(next)
                    entries.append(Entry(state: next, parent: item.index, move: PuzzleMove(source: source, destination: destination), cost: cost, bound: heuristic))
                    push(Item(index: entries.count - 1, total: cost + heuristic, bound: heuristic))
                }
            }
        }
        return SolverAnalysis(result: .unsolvable, exploredStates: explored)
    }
}
