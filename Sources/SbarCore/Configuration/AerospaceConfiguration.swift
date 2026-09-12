import Foundation

struct AerospaceConfiguration: Codable, Equatable, Sendable {
  var scope: AerospaceScope?
  var format: AerospaceFormat?
  var labels: [String: String]?
  var symbols: AvailabilitySymbols?
  var tints: AerospaceTints?
  var showValue: Bool?
  var showSymbol: Bool?

  func validate(path: String) throws {
    for key in (labels ?? [:]).keys {
      guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ConfigurationError.invalidValue(
          path: "\(path).labels",
          reason: "Label keys must be nonblank workspace names."
        )
      }
    }
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")
  }
}

enum AerospaceScope: String, Codable, Sendable {
  case focused, display
}

enum AerospaceFormat: String, Codable, Sendable {
  case current, list
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
