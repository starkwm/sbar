import Foundation

struct BatteryConfiguration: Codable, Equatable, Sendable {
  var symbols: BatterySymbols?
  var tints: BatteryTints?
  var showPercentage: Bool?
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

struct BatterySymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var levels: [BatterySymbol]?
  var charging: BatterySymbol?
  var pluggedIn: BatterySymbol?

  func validate(path: String) throws {
    if let font, font.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw ConfigurationError.invalidValue(path: "\(path).font", reason: "Must not be blank.")
    }
    if let size, !(8...72).contains(size) {
      throw ConfigurationError.invalidValue(
        path: "\(path).size",
        reason: "Must be between 8 and 72."
      )
    }
    if let levels, levels.count != 5 {
      throw ConfigurationError.invalidValue(
        path: "\(path).levels",
        reason: "Provide five symbols for 0, 25, 50, 75, and 100 percent."
      )
    }
    for (index, symbol) in (levels ?? []).enumerated() {
      try symbol.validate(font: font, path: "\(path).levels[\(index)]")
    }
    try charging?.validate(font: font, path: "\(path).charging")
    try pluggedIn?.validate(font: font, path: "\(path).pluggedIn")
  }

  func resolve(_ symbol: BatterySymbol?) -> ItemSymbol? {
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

enum BatterySymbol: Codable, Equatable, Sendable {
  case system(String)
  case glyph(String, font: String? = nil, size: Double? = nil)

  private enum CodingKeys: String, CodingKey { case glyph, font, size }

  init(from decoder: any Decoder) throws {
    if let name = try? decoder.singleValueContainer().decode(String.self) {
      self = .system(name)
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self = .glyph(
      try container.decode(String.self, forKey: .glyph),
      font: try container.decodeIfPresent(String.self, forKey: .font),
      size: try container.decodeIfPresent(Double.self, forKey: .size)
    )
  }

  func encode(to encoder: any Encoder) throws {
    switch self {
    case .system(let name):
      var container = encoder.singleValueContainer()
      try container.encode(name)
    case .glyph(let glyph, let font, let size):
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(glyph, forKey: .glyph)
      try container.encodeIfPresent(font, forKey: .font)
      try container.encodeIfPresent(size, forKey: .size)
    }
  }

  func validate(font inheritedFont: String?, path: String) throws {
    guard case .glyph(let glyph, let font, let size) = self else { return }
    guard !glyph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let resolvedFont = font ?? inheritedFont,
      !resolvedFont.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      size.map({ (8...72).contains($0) }) ?? true
    else {
      throw ConfigurationError.invalidValue(
        path: path,
        reason:
          "Glyph must not be blank, a font must be provided or inherited, and size must be between 8 and 72."
      )
    }
  }

  func resolve(font inheritedFont: String?, size inheritedSize: Double?) -> ItemSymbol? {
    switch self {
    case .system(let name):
      return .system(name)
    case .glyph(let glyph, let font, let size):
      guard let font = font ?? inheritedFont else { return nil }
      return .glyph(glyph, font: font, size: size ?? inheritedSize)
    }
  }
}
