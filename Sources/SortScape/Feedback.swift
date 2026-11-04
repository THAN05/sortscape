import SwiftUI
import AVFoundation
import UIKit

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults: UserDefaults
    @Published var sound: Bool { didSet { defaults.set(sound, forKey: "sound") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    @Published var reduceMotion: Bool { didSet { defaults.set(reduceMotion, forKey: "reduceMotion") } }
    private init() {
        #if DEBUG
        if let namespace = ProcessInfo.processInfo.environment["SORTSCAPE_TEST_SAVE"] {
            defaults = UserDefaults(suiteName: "SortScapeTests.\(namespace)") ?? .standard
        } else { defaults = .standard }
        #else
        defaults = .standard
        #endif
        sound = defaults.object(forKey: "sound") as? Bool ?? true
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        reduceMotion = defaults.bool(forKey: "reduceMotion")
    }
}

/// AVAudioPlayer is confined to this serial queue; it never crosses queue boundaries.
private final class SoundPlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.sortscape.sound", qos: .userInitiated)
    private var players: [String: AVAudioPlayer] = [:]
    init() {
        queue.async { [self] in
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            for name in ["move", "invalid", "complete"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                   let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = 0.32; player.prepareToPlay(); players[name] = player
                }
            }
        }
    }
    func play(_ name: String) {
        queue.async { [self] in
            guard let player = players[name] else { return }
            player.currentTime = 0; player.play()
        }
    }
    func stop() { queue.async { [self] in players.values.forEach { $0.stop() } } }
}

@MainActor
final class GameFeedback {
    enum Event: String, Sendable { case move, invalid, complete }
    private static let sharedAudio = SoundPlayer()
    private var audio: SoundPlayer { Self.sharedAudio }
    func play(_ event: Event) {
        if AppSettings.shared.sound { audio.play(event.rawValue) }
        guard AppSettings.shared.haptics else { return }
        switch event {
        case .move: UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        case .invalid: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .complete: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    func stop() { audio.stop() }
}
