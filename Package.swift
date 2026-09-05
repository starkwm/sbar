// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "sbar",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "sbar", targets: ["Sbar"])],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1")
  ],
  targets: [
    .executableTarget(
      name: "Sbar",
      dependencies: [
        "SbarCore", .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .target(name: "SbarCore", resources: [.copy("Resources/config.schema.json")]),
    .testTarget(name: "SbarTests", dependencies: ["Sbar"]),
    .testTarget(name: "SbarCoreTests", dependencies: ["SbarCore"]),
  ]
)
