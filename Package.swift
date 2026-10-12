// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BlogCoverMakerBySeolin",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "CoverCore", targets: ["CoverCore"])],
    targets: [
        .target(name: "CoverCore", resources: [.process("Resources")]),
        .testTarget(name: "CoverCoreTests", dependencies: ["CoverCore"])
    ]
)
