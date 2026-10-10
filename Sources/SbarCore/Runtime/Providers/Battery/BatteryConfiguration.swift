import Foundation

struct BatteryConfiguration: Codable, Equatable, Sendable {
  var symbols: BatterySymbols?
  var tints: BatteryTints?
  var showSymbol: Bool?
  var lowThreshold: Int?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")

    if let lowThreshold, !(0...100).contains(lowThreshold) {
      throw ConfigurationError.invalidValue(
        path: "\(path).lowThreshold",
        reason: "Must be between 0 and 100."
      )
    }
  }
}

struct BatterySymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var levels: [WidgetSymbol]?
  var chargingLevels: [WidgetSymbol]?
  var charging: WidgetSymbol?
  var pluggedIn: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)

    for (name, values) in [("levels", levels), ("chargingLevels", chargingLevels)] {
      if let values, values.count != 5 {
        throw ConfigurationError.invalidValue(
          path: "\(path).\(name)",
          reason: "Provide five symbols for 0, 25, 50, 75, and 100 percent."
        )
      }
      for (index, symbol) in (values ?? []).enumerated() {
        try symbol.validate(font: font, path: "\(path).\(name)[\(index)]")
      }
    }

    try charging?.validate(font: font, path: "\(path).charging")
    try pluggedIn?.validate(font: font, path: "\(path).pluggedIn")
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}

struct BatteryTints: Codable, Equatable, Sendable {
  var low: String?
  var charging: String?
  var pluggedIn: String?

  func validate(path: String) throws {
    try ItemStyle.validateColor(low, path: "\(path).low")
    try ItemStyle.validateColor(charging, path: "\(path).charging")
    try ItemStyle.validateColor(pluggedIn, path: "\(path).pluggedIn")
  }
}
