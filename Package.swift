// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "sbar",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "sbar", targets: ["sbar"]),
    .executable(name: "sbarctl", targets: ["sbarctl"]),
  ],
  targets: [
    .target(name: "ControlProtocol"),
    .executableTarget(name: "sbarctl", dependencies: ["ControlProtocol"]),
    .executableTarget(
      name: "sbar",
      dependencies: ["ControlProtocol"],
      resources: [.copy("Resources/config.schema.json")]
    ),
    .testTarget(name: "sbarTests", dependencies: ["sbar"], path: "Tests"),
  ]
)
