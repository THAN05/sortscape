// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PuzzleCore", products: [.library(name: "PuzzleCore", targets: ["PuzzleCore"]), .executable(name: "CampaignTool", targets: ["CampaignTool"])], targets: [.target(name: "PuzzleCore", resources: [.process("Resources")]), .executableTarget(name: "CampaignTool", dependencies: ["PuzzleCore"]), .testTarget(name: "PuzzleCoreTests", dependencies: ["PuzzleCore"])])
