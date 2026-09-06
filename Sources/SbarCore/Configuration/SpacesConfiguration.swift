import Foundation

struct SpacesConfiguration: Codable, Equatable, Sendable {
  var scope: SpacesScope?
  var format: SpacesFormat?
  var labels: [String: String]?
  var symbols: SpacesSymbols?
  var tints: SpacesTints?
  var includeFullscreen: Bool?
  var showValue: Bool?
  var showSymbol: Bool?

  func validate(path: String) throws {
    for key in (labels ?? [:]).keys {
      guard let index = Int(key), index > 0, String(index) == key else {
        throw ConfigurationError.invalidValue(
          path: "\(path).labels",
          reason: "Label keys must be positive one-based indexes."
        )
      }
    }
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")
  }
}

enum SpacesScope: String, Codable, Sendable {
  case focused, display
}

enum SpacesFormat: String, Codable, Sendable {
  case current, currentTotal, list
}

struct SpacesSymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var available: WidgetSymbol?
  var unavailable: WidgetSymbol?

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
    try available?.validate(font: font, path: "\(path).available")
    try unavailable?.validate(font: font, path: "\(path).unavailable")
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}

struct SpacesTints: Codable, Equatable, Sendable {
  var active: String?
  var inactive: String?
  var unavailable: String?

  func validate(path: String) throws {
    for (key, tint) in [("active", active), ("inactive", inactive), ("unavailable", unavailable)] {
      try ItemStyle.validateColor(tint, path: "\(path).\(key)")
    }
  }
}
