import Foundation

public enum AdReward: Codable, Equatable, Sendable {
    case hint, undo, levelCoins(Int)
    public var description: String {
        switch self {
        case .hint: "Watch one optional ad to save one hint that applies a move automatically. Free hints remain available on levels where you have not used a hint."
        case .undo: "Watch one optional ad to save one two-move rewind. Normal Undo remains free."
        case .levelCoins: "Watch one optional ad to earn 25 bonus coins. Available once per completed world."
        }
    }
}
public struct AdRewardState: Codable, Equatable, Sendable {
    public internal(set) var claims: [String: AdReward] = [:]
    public internal(set) var hintsUsed = 0
    public internal(set) var undosUsed = 0
    public var hints: Int { claims.values.filter { $0 == .hint }.count - hintsUsed }
    public var undos: Int { claims.values.filter { $0 == .undo }.count - undosUsed }
    public func hasBonus(for level: Int) -> Bool { claims.values.contains(.levelCoins(level)) }
    public init() {}
    var isValid: Bool {
        claims.count <= 100_000 && claims.keys.allSatisfy { UUID(uuidString: $0) != nil } &&
        claims.values.allSatisfy { if case .levelCoins(let id) = $0 { return (1...100).contains(id) }; return true } &&
        hintsUsed >= 0 && undosUsed >= 0 && hints >= 0 && undos >= 0
    }
}

/// Frequency policy contains no SDK/UI code. Wall-clock values persist across launches;
/// future timestamps fail closed after clock rollback. A session is one app process.
public struct AdFrequencyManager: Codable, Equatable, Sendable {
    public private(set) var sessions = 0
    public private(set) var sessionStarted: Date?
    public private(set) var lastFullscreen: Date?
    public private(set) var lastInterstitial: Date?
    public private(set) var day = 0
    public private(set) var fullscreenToday = 0
    public private(set) var interstitialsToday = 0
    public private(set) var interstitialsThisSession = 0
    public init() {}
    public mutating func beginSession(at now: Date) {
        sessions = min(sessions + 1, 1_000_000); sessionStarted = now; interstitialsThisSession = 0
    }
    public func allowsRewarded(at now: Date) -> Bool {
        (Self.dayNumber(now) > day || fullscreenToday < 8) &&
        (lastFullscreen.map { now.timeIntervalSince($0) >= 30 } ?? true)
    }
    public func allowsInterstitial(completedLevels: Int, betweenLevels: Bool, removesAds: Bool, at now: Date) -> Bool {
        guard sessions > 1, betweenLevels, !removesAds, completedLevels >= 4,
              let sessionStarted, now.timeIntervalSince(sessionStarted) >= 180,
              interstitialsThisSession < 2,
              Self.dayNumber(now) > day || (interstitialsToday < 3 && fullscreenToday < 8) else { return false }
        return (lastFullscreen.map { now.timeIntervalSince($0) >= 180 } ?? true) &&
            (lastInterstitial.map { now.timeIntervalSince($0) >= 180 } ?? true)
    }
    public mutating func recordPresentation(interstitial: Bool, at now: Date) {
        let current = Self.dayNumber(now)
        if current > day { day = current; fullscreenToday = 0; interstitialsToday = 0 }
        fullscreenToday = min(fullscreenToday + 1, 1_000_000); lastFullscreen = now
        if interstitial {
            interstitialsToday = min(interstitialsToday + 1, 1_000_000)
            interstitialsThisSession = min(interstitialsThisSession + 1, 1_000_000); lastInterstitial = now
        }
    }
    private static func dayNumber(_ now: Date) -> Int { Int(now.timeIntervalSince1970 / 86_400) }
}
