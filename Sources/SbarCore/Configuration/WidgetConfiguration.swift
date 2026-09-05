struct BatteryConfiguration: Codable, Equatable, Sendable {
  var showPercentage: Bool?
  var showSymbol: Bool?
  var levelSymbols: [ItemSymbol]?
  var chargingSymbol: ItemSymbol?
  var pluggedInSymbol: ItemSymbol?
  var lowThreshold: Int?
  var lowTint: String?
  var chargingTint: String?
  var pluggedInTint: String?

  func validate(path: String) throws {
    if let levelSymbols, levelSymbols.count != 5 {
      throw ConfigurationError.invalidValue(
        path: "\(path).levelSymbols",
        reason: "Provide five symbols for 0, 25, 50, 75, and 100 percent."
      )
    }
    if let lowThreshold, !(0...100).contains(lowThreshold) {
      throw ConfigurationError.invalidValue(
        path: "\(path).lowThreshold",
        reason: "Must be between 0 and 100."
      )
    }
    try ItemStyle.validateColor(lowTint, path: "\(path).lowTint")
    try ItemStyle.validateColor(chargingTint, path: "\(path).chargingTint")
    try ItemStyle.validateColor(pluggedInTint, path: "\(path).pluggedInTint")
  }
}

struct WifiConfiguration: Codable, Equatable, Sendable {
  var showLabel: Bool?
  var showSymbol: Bool?
  var connectedLabel: String?
  var disconnectedLabel: String?
  var connectedSymbol: ItemSymbol?
  var disconnectedSymbol: ItemSymbol?
  var connectedTint: String?
  var disconnectedTint: String?
  var hideWhenDisconnected: Bool?

  func validate(path: String) throws {
    try ItemStyle.validateColor(connectedTint, path: "\(path).connectedTint")
    try ItemStyle.validateColor(disconnectedTint, path: "\(path).disconnectedTint")
  }
}
