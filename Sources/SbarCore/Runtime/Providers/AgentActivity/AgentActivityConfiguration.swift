import Foundation

struct AgentActivityConfiguration: Codable, Equatable, Sendable {
  var sources: [String]?
  var projects: [String]?
  var finishedRetention: Double?
  var staleAfter: Double?
  var hideWhenEmpty: Bool?
  var showSymbol: Bool?
  var symbols: [String: WidgetSymbol]?
  var font: String?
  var size: Double?
  var tints: [String: String]?

  func validate(path: String) throws {
    for value in [finishedRetention, staleAfter].compactMap({ $0 }) {
      guard value.isFinite && (1...86400).contains(value) else {
        throw ConfigurationError.invalidValue(
          path: path,
          reason: "Retention and staleAfter must be 1...86400 seconds."
        )
      }
    }
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)
    for (key, symbol) in symbols ?? [:] {
      guard AgentActivityStatus(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: path + ".symbols." + key,
          reason: "Unknown agent state."
        )
      }
      try symbol.validate(font: font, path: path + ".symbols." + key)
    }
    for (key, tint) in tints ?? [:] {
      guard AgentActivityStatus(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: path + ".tints." + key,
          reason: "Unknown agent state."
        )
      }
      try ItemStyle.validateColor(tint, path: path + ".tints." + key)
    }
  }
}
