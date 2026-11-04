import SwiftUI
import SpriteKit
import PuzzleCore

struct AssistancePolicy: Sendable {
    let maximumSearchStates: Int
    init(maximumSearchStates: Int = 50_000) { self.maximumSearchStates = min(100_000, max(1_000, maximumSearchStates)) }
}

@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var session: PuzzleSession
    @Published private(set) var message = "Pick a piece. Find its place."
    @Published private(set) var selected: Int?
    @Published private(set) var busy = false
    @Published private(set) var findingHint = false
    @Published var paused = false
    @Published var completionReady = false
    let scene = PuzzleScene(size: CGSize(width: 390, height: 520))
    private let checkpoint: PuzzleCheckpointStore?
    @Published private(set) var checkpointError: String?
    private let assistance: AssistancePolicy
    private let telemetry: LevelTelemetry
    private let feedback = GameFeedback()
    private var animationTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private var usedHint = false
    private var hintGeneration = UUID()
    var reduceMotion = false { didSet { scene.reduceMotion = reduceMotion } }
    var acceptsInput: Bool { !busy && !findingHint && !paused && !session.state.isSolved }

    init(level: Level, analytics: Telemetry = .shared, assistance: AssistancePolicy = AssistancePolicy(), checkpoint: PuzzleCheckpointStore? = nil) {
        self.assistance = assistance
        telemetry = LevelTelemetry(level: level, telemetry: analytics)
        self.checkpoint = checkpoint
        session = PuzzleSession(state: level.state)
        do {
            if let restored = try checkpoint?.load() {
                session = restored
                completionReady = restored.state.isSolved
                message = "Your puzzle was recovered."
            }
        } catch { checkpointError = "This saved puzzle could not be recovered. Your rewards are unchanged." }
        scene.scaleMode = .resizeFill
        scene.onSelect = { [weak self] in self?.select($0) }
        refresh()
    }

    func select(_ index: Int) {
        guard acceptsInput, session.state.containers.indices.contains(index) else { return }
        guard let source = selected else {
            if !session.state.containers[index].isEmpty { selected = index; message = "Choose a matching top or an empty vessel."; refresh() }
            return
        }
        if source == index { selected = nil; message = "Selection cleared."; refresh(); return }
        let previous = session.state
        guard session.move(from: source, to: index) else {
            message = "That piece needs a matching top or an empty vessel."
            feedback.play(.invalid); scene.invalid(at: index)
            UIAccessibility.post(notification: .announcement, argument: message)
            return
        }
        saveCheckpoint()
        selected = nil; busy = true; feedback.play(.move)
        message = "A little closer to calm."
        scene.animateMove(from: source, to: index, previous: previous)
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            guard let self else { return }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(450)) }
            guard !Task.isCancelled else { return }
            finishAnimation()
        }
    }

    private func finishAnimation() {
        busy = false; refresh()
        if session.state.isSolved {
            telemetry.complete(moves: session.moveCount)
            message = "Beautifully sorted. World restored!"
            scene.celebrate(); feedback.play(.complete); completionReady = true
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    func undo() {
        guard !busy && !findingHint, session.canUndo else { return }
        telemetry.undo(moves: session.moveCount)
        session.undo(); saveCheckpoint(); selected = nil; completionReady = false; message = "Room to try another way."; refresh()
    }
    func rewind(spend: () -> Bool) {
        guard acceptsInput, session.moveCount >= 2, spend() else { return }
        telemetry.undo(moves: session.moveCount)
        session.undo(); session.undo(); saveCheckpoint(); selected = nil; completionReady = false
        message = "Two moves rewound. A little extra room."; refresh()
    }
    func restart() {
        guard !busy && !findingHint else { return }
        telemetry.restart(moves: session.moveCount)
        session.restart(); saveCheckpoint(); selected = nil; completionReady = false; message = "A fresh beginning."; refresh()
    }
    func pause() {
        animationTask?.cancel(); cancelHint()
        if busy { finishAnimation() }
        telemetry.pause()
        paused = true; feedback.stop(); scene.isPaused = true
    }
    func resume() { if !session.state.isSolved { telemetry.resume() }; paused = false; scene.isPaused = false; refresh() }
    func leave() {
        telemetry.abandon(moves: session.moveCount)
        animationTask?.cancel(); cancelHint(); busy = false; feedback.stop(); scene.removeAllActions()
    }
    func hint(record: @escaping @MainActor () -> Bool = { true }, applyMove: (@MainActor () -> Bool)? = nil) {
        guard acceptsInput, !usedHint else { return }
        findingHint = true; selected = nil; message = "Finding a gentle nudge…"; refresh()
        let maximumStates = assistance.maximumSearchStates
        let snapshot = session.state, generation = UUID(); hintGeneration = generation
        hintTask = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) { PuzzleSolver().solve(snapshot, maximumStates: maximumStates) }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard let self, !Task.isCancelled, generation == hintGeneration, snapshot == session.state else { return }
            findingHint = false
            switch result {
            case .solved(let moves):
                if let first = moves.first {
                    if let applyMove {
                        if applyMove() {
                            usedHint = true
                            telemetry.hint(moves: session.moveCount)
                            selected = nil; select(first.source); select(first.destination)
                        } else { message = "No hint token was used. Check your balance or try saving again." }
                        return
                    }
                    guard record() else { message = "The hint could not be saved."; return }
                    usedHint = true
                    telemetry.hint(moves: session.moveCount)
                    selected = first.source
                    message = "Try vessel \(first.source + 1) → vessel \(first.destination + 1)."
                }
            case .unsolvable: message = "This path is blocked. Try Undo or Restart."
            case .searchLimitReached: message = "No hint found within the search limit. Try Undo."
            }
            refresh(); UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    private func cancelHint() {
        hintGeneration = UUID(); hintTask?.cancel()
        if findingHint { message = "Hint paused. Tap Hint when you’re ready." }
        findingHint = false
    }
    func clearCompletedCheckpoint() {
        guard session.state.isSolved else { return }
        writeCheckpoint(nil)
    }
    private func saveCheckpoint() { writeCheckpoint(session.moveCount == 0 ? nil : session) }
    private func writeCheckpoint(_ value: PuzzleSession?) {
        do { try checkpoint?.save(value); checkpointError = nil }
        catch { checkpointError = "This puzzle could not be saved. You can keep playing." }
    }
    private func refresh() { scene.render(state: session.state, selected: selected) }

    func containerLabel(_ index: Int) -> String {
        let pieces = session.state.containers[index]
        let contents = pieces.isEmpty ? "empty" : "bottom to top: " + pieces.map(\.spokenName).joined(separator: ", ")
        return "Vessel \(index + 1), \(pieces.count) of 4, \(contents)\(selected == index ? ", selected" : "")"
    }
}
