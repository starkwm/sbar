import Foundation

struct SpacesConfiguration: Codable, Equatable, Sendable {
  var scope: SpacesScope?
  var names: [SpaceName?]?
  var symbols: AvailabilitySymbols?
  var tints: SpacesTints?
  var includeFullscreen: Bool?
  var showSymbol: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")
  }
}

enum SpacesScope: String, Codable, Sendable {
  case focused, display
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
