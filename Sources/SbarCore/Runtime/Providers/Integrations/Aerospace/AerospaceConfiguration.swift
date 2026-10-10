import Foundation

struct AerospaceConfiguration: Codable, Equatable, Sendable {
  var scope: AerospaceScope?
  var symbols: AvailabilitySymbols?
  var tints: AerospaceTints?
  var showSymbol: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")
  }
}

enum AerospaceScope: String, Codable, Sendable {
  case focused, display
}

struct AerospaceTints: Codable, Equatable, Sendable {
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
