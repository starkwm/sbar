// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StarkBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StarkBar", targets: ["StarkBar"])],
    targets: [
        .executableTarget(name: "StarkBar", path: "Sources"),
        .testTarget(name: "StarkBarTests", dependencies: ["StarkBar"], path: "Tests"),
    ]
)
