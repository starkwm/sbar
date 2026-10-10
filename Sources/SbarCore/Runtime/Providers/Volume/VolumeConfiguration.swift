import Foundation

struct VolumeConfiguration: Codable, Equatable, Sendable {
  var symbols: VolumeSymbols?
  var tints: VolumeTints?
  var showSymbol: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")
  }
}

struct VolumeSymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var levels: [WidgetSymbol]?
  var muted: WidgetSymbol?
  var fixed: WidgetSymbol?
  var unavailable: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)

    if let levels, levels.count != 4 {
      throw ConfigurationError.invalidValue(
        path: "\(path).levels",
        reason: "Provide four symbols for zero, low, medium, and high volume."
      )
    }
    for (index, symbol) in (levels ?? []).enumerated() {
      try symbol.validate(font: font, path: "\(path).levels[\(index)]")
    }

    try muted?.validate(font: font, path: "\(path).muted")
    try fixed?.validate(font: font, path: "\(path).fixed")
    try unavailable?.validate(font: font, path: "\(path).unavailable")
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}

struct VolumeTints: Codable, Equatable, Sendable {
  var muted: String?
  var fixed: String?
  var unavailable: String?

  func validate(path: String) throws {
    try ItemStyle.validateColor(muted, path: "\(path).muted")
    try ItemStyle.validateColor(fixed, path: "\(path).fixed")
    try ItemStyle.validateColor(unavailable, path: "\(path).unavailable")
  }
}
