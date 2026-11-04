import Foundation
import PuzzleCore

/// Recovery is separate from the wallet; a checkpoint can never grant rewards by itself.
struct PuzzleCheckpointStore {
    let url: URL
    let level: Level
    private static let maximumMoves = 20_000
    private static let maximumBytes = 1_000_000

    private struct Record: Codable {
        let version: Int
        let board: [[PieceColor]]
        let moves: [PuzzleMove]
    }

    static func application(level: Level) -> Self {
        var directory = URL.applicationSupportDirectory.appending(path: "SortScape/Attempts")
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"], UUID(uuidString: id) != nil {
            directory = directory.appending(path: id)
        }
        #endif
        return Self(url: directory.appending(path: "\(level.id).json"), level: level)
    }

    func load() throws -> PuzzleSession? {
        let data: Data
        do {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            data = try file.read(upToCount: Self.maximumBytes + 1) ?? Data()
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
        guard data.count <= Self.maximumBytes else { throw CocoaError(.fileReadCorruptFile) }
        let record = try JSONDecoder().decode(Record.self, from: data)
        guard record.version == 1, record.board == level.state.containers,
              !record.moves.isEmpty, record.moves.count <= Self.maximumMoves else { throw CocoaError(.fileReadCorruptFile) }
        var session = PuzzleSession(state: level.state)
        for move in record.moves {
            guard !session.state.isSolved, session.move(from: move.source, to: move.destination) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
        return session
    }

    func save(_ session: PuzzleSession?) throws {
        guard let session else {
            do { try FileManager.default.removeItem(at: url) }
            catch let error as CocoaError where error.code == .fileNoSuchFile {}
            return
        }
        guard session.initialState == level.state, session.moveCount <= Self.maximumMoves else {
            throw CocoaError(.fileWriteUnknown)
        }
        let record = Record(version: 1, board: level.state.containers, moves: session.moves)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: url, options: .atomic)
    }
}
