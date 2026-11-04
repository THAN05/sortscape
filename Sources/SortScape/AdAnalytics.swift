import Foundation

/// On-device aggregate counters only. No identifiers, precise timestamps, SDK error
/// strings, user profiles, network exporter, or third-party analytics are collected.
@MainActor
final class AdAnalytics {
    struct Snapshot: Codable {
        var version = 1
        var counters: [String: Int] = [:]
        var revenueMicros: [String: Int64] = [:]
        var firstDay: Int?
        var returnedDays: Set<Int> = []
        var adExposedDays: Set<Int> = []
    }
    private(set) var snapshot: Snapshot
    private let defaults: UserDefaults
    private let key = "ads.metrics.v1"
    init(defaults: UserDefaults) {
        self.defaults = defaults
        snapshot = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
    }
    func session(at date: Date) {
        let day = Int(date.timeIntervalSince1970 / 86_400)
        if snapshot.firstDay == nil { snapshot.firstDay = day }
        snapshot.returnedDays.insert(day); increment("session_start")
        if snapshot.returnedDays.count > 366 { snapshot.returnedDays = Set(snapshot.returnedDays.sorted().suffix(366)) }
        save()
    }
    func increment(_ key: String) { snapshot.counters[key] = min(snapshot.counters[key, default: 0] + 1, 1_000_000_000); save() }
    func record(_ event: AdEvent, at now: Date) {
        switch event {
        case .load(let format): increment("\(format.rawValue)_load")
        case .loaded(let format): increment("\(format.rawValue)_loaded")
        case .show(let format): increment("\(format.rawValue)_show")
        case .impression(let format):
            snapshot.adExposedDays.insert(Int(now.timeIntervalSince1970 / 86_400))
            if snapshot.adExposedDays.count > 366 { snapshot.adExposedDays = Set(snapshot.adExposedDays.sorted().suffix(366)) }
            increment("\(format.rawValue)_impression")
        case .dismissed(let format): increment("\(format.rawValue)_dismissed")
        case .failed(let format): increment("\(format.rawValue)_failure")
        case .earned: break // Count completion exactly once in the reward-ticket callback.
        case .revenue(_, let value, let currency):
            guard value.isFinite, value >= 0, value < 1_000_000,
                  currency.count == 3, currency.utf8.allSatisfy({ (65...90).contains($0) }) else { return }
            let amount = Int64((value * 1_000_000).rounded())
            snapshot.revenueMicros[currency] = min(snapshot.revenueMicros[currency, default: 0], Int64.max - amount) + amount
            save()
        }
    }
    private func save() { if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: key) } }
}
