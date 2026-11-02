// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "sbar",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "sbar", targets: ["Sbar"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
    .package(url: "https://github.com/starkwm/stark-configuration", from: "0.0.3"),
    .package(url: "https://github.com/starkwm/stark-ipc", from: "0.0.5"),
  ],
  targets: [
    .executableTarget(
      name: "Sbar",
      dependencies: [
        "SbarCore", .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      exclude: ["Info.plist", "Version.swift.tmpl"],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
          "-Xlinker", Context.packageDirectory + "/Sources/Sbar/Info.plist",
        ])
      ]
    ),
    .target(
      name: "SbarCore",
      dependencies: [
        .product(name: "StarkConfiguration", package: "stark-configuration"),
        .product(name: "StarkIPC", package: "stark-ipc"),
      ],
      exclude: ["Resources"]
    ),
    .testTarget(name: "SbarTests", dependencies: ["Sbar"]),
    .testTarget(
      name: "SbarCoreTests",
      dependencies: ["SbarCore", .product(name: "StarkIPC", package: "stark-ipc")]
    ),
  ]
)
