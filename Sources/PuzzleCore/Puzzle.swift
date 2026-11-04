public enum PieceColor: Int, CaseIterable, Sendable, Codable {
    case coral, ocean, mint, gold
}

public struct PuzzleState: Equatable, Hashable, Sendable {
    public static let capacity = 4
    /// Each container is ordered bottom to top.
    public private(set) var containers: [[PieceColor]]

    public init(containers: [[PieceColor]]) {
        precondition(!containers.isEmpty && containers.allSatisfy { $0.count <= Self.capacity })
        self.containers = containers
    }

    public var isSolved: Bool {
        containers.allSatisfy { $0.isEmpty || ($0.count == Self.capacity && Set($0).count == 1) }
    }

    public func canMove(from source: Int, to destination: Int) -> Bool {
        guard containers.indices.contains(source), containers.indices.contains(destination),
              source != destination, let color = containers[source].last,
              containers[destination].count < Self.capacity else { return false }
        return containers[destination].last.map { $0 == color } ?? true
    }

    @discardableResult
    public mutating func move(from source: Int, to destination: Int) -> Bool {
        guard canMove(from: source, to: destination) else { return false }
        containers[destination].append(containers[source].removeLast())
        return true
    }
}

public struct PuzzleSession: Sendable {
    public let initialState: PuzzleState
    public private(set) var state: PuzzleState
    public private(set) var moves: [PuzzleMove] = []
    private var history: [PuzzleState] = []
    public var moveCount: Int { history.count }
    public var canUndo: Bool { !history.isEmpty }

    public init(state: PuzzleState) { initialState = state; self.state = state }

    @discardableResult
    public mutating func move(from: Int, to: Int) -> Bool {
        let previous = state
        guard state.move(from: from, to: to) else { return false }
        history.append(previous)
        moves.append(PuzzleMove(source: from, destination: to))
        return true
    }

    public mutating func undo() {
        guard let previous = history.popLast() else { return }
        moves.removeLast()
        state = previous
    }

    public mutating func restart() { state = initialState; history.removeAll(); moves.removeAll() }
}

