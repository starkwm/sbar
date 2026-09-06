import Foundation

struct YabaiConfiguration: Codable, Equatable, Sendable {
  var scope: YabaiScope?
  var format: YabaiFormat?
  var includeFullscreen: Bool?
  var symbols: YabaiSymbols?
  var tints: YabaiTints?
  var showValue: Bool?
  var showSymbol: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")
  }
}

enum YabaiScope: String, Codable, Sendable {
  case focused, display
}

enum YabaiFormat: String, Codable, Sendable {
  case current, list
}

struct YabaiSymbols: Codable, Equatable, Sendable {
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

struct YabaiTints: Codable, Equatable, Sendable {
  var focused: String?
  var visible: String?
  var inactive: String?
  var unavailable: String?

  func validate(path: String) throws {
    for (key, tint) in [
      ("focused", focused), ("visible", visible), ("inactive", inactive),
      ("unavailable", unavailable),
    ] {
      try ItemStyle.validateColor(tint, path: "\(path).\(key)")
    }
  }
}
