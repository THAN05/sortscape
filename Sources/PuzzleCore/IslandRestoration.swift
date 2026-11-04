public enum DecorationID: String, Codable, CaseIterable, Sendable {
    case pathways, trees, flowerGarden, cottage, bridge, picnic, fountain, windmill, dock, lighthouse
}
public struct RestorationItem: Identifiable, Equatable, Sendable {
    public let id: DecorationID
    public let name: String
    public let detail: String
    public let icon: String
    let preIncreaseCost: Int
    public var cost: Int { preIncreaseCost * 10 }
    public let requiredLevels: Int
    public let requiredStars: Int
    public let prerequisite: DecorationID?
    public let column: Int
    public let row: Int

    // Match transactions from saves written before the campaign rebalance.
    var previousTerms: (cost: Int, requiredClears: Int)? {
        switch id {
        case .bridge: (90, 8)
        case .picnic: (80, 10)
        case .fountain: (120, 15)
        case .windmill: (150, 20)
        case .dock: (160, 25)
        case .lighthouse: (200, 30)
        default: nil
        }
    }

    public static let all: [RestorationItem] = [
        .init(id: .pathways, name: "Decorative pathways", detail: "The first steps toward a place of your own.", icon: "point.topleft.down.to.point.bottomright.curvepath", preIncreaseCost: 20, requiredLevels: 1, requiredStars: 1, prerequisite: nil, column: 0, row: 0),
        .init(id: .trees, name: "Island trees", detail: "A little shade. A lot of life.", icon: "tree.fill", preIncreaseCost: 30, requiredLevels: 2, requiredStars: 2, prerequisite: nil, column: -2, row: 0),
        .init(id: .flowerGarden, name: "Flower garden", detail: "Color blooms beyond the puzzle board.", icon: "camera.macro", preIncreaseCost: 45, requiredLevels: 3, requiredStars: 3, prerequisite: .pathways, column: 1, row: -1),
        .init(id: .cottage, name: "Small cottage", detail: "A warm little home overlooking the sea.", icon: "house.fill", preIncreaseCost: 70, requiredLevels: 5, requiredStars: 5, prerequisite: .pathways, column: -1, row: -1),
        .init(id: .bridge, name: "Wooden bridge", detail: "Connect quiet corners of your island.", icon: "point.topleft.down.to.point.bottomright.curvepath", preIncreaseCost: 160, requiredLevels: 8, requiredStars: 8, prerequisite: .pathways, column: 2, row: 0),
        .init(id: .picnic, name: "Picnic area", detail: "Make room for slow afternoons.", icon: "basket.fill", preIncreaseCost: 270, requiredLevels: 25, requiredStars: 25, prerequisite: .trees, column: -2, row: -1),
        .init(id: .fountain, name: "Fountain", detail: "A soothing sparkle at the heart of it all.", icon: "drop.fill", preIncreaseCost: 420, requiredLevels: 40, requiredStars: 40, prerequisite: .flowerGarden, column: 0, row: -1),
        .init(id: .windmill, name: "Windmill", detail: "Catch the breeze above the garden.", icon: "wind", preIncreaseCost: 540, requiredLevels: 60, requiredStars: 60, prerequisite: .cottage, column: -1, row: -2),
        .init(id: .dock, name: "Dock", detail: "A welcoming edge where land meets water.", icon: "sailboat.fill", preIncreaseCost: 650, requiredLevels: 80, requiredStars: 80, prerequisite: .bridge, column: 2, row: 1),
        .init(id: .lighthouse, name: "Lighthouse", detail: "A beacon for every new possibility.", icon: "light.beacon.max.fill", preIncreaseCost: 950, requiredLevels: 100, requiredStars: 100, prerequisite: .bridge, column: 1, row: -2)
    ]
}
public enum RestorationStatus: Equatable, Sendable {
    case restored, locked, available, insufficientCoins
}
public enum RestorationResult: Equatable, Sendable {
    case restored(milestoneCoins: Int), alreadyRestored, locked, insufficientCoins(needed: Int), invalidTransaction
}
public struct IslandProgress: Codable, Equatable, Sendable {
    public internal(set) var restored: Set<DecorationID> = []
    public init() {}
    public var completionPercentage: Int { restored.count * 100 / RestorationItem.all.count }
}
