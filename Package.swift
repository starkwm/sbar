// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "StarkBar",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "StarkBar", targets: ["StarkBar"]),
    .executable(name: "barctl", targets: ["barctl"]),
  ],
  targets: [
    .target(name: "ControlProtocol", path: "Shared/ControlProtocol"),
    .executableTarget(name: "barctl", dependencies: ["ControlProtocol"], path: "CLI"),
    .executableTarget(
      name: "StarkBar",
      dependencies: ["ControlProtocol"],
      path: "Sources",
      resources: [.copy("Resources/config.schema.json")]
    ),
    .testTarget(name: "StarkBarTests", dependencies: ["StarkBar"], path: "Tests"),
  ]
)
