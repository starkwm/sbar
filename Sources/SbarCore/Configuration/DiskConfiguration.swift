import Foundation

struct DiskConfiguration: Codable, Equatable, Sendable {
  var path: String?
  var symbols: AvailabilitySymbols?
  var tints: DiskTints?
  var showSymbol: Bool?
  var warningThreshold: Int?
  var criticalThreshold: Int?

  var resolvedPath: String {
    (path.map { ($0 as NSString).expandingTildeInPath } ?? NSHomeDirectory())
  }

  func validate(path location: String) throws {
    if let path,
      path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !resolvedPath.hasPrefix("/")
    {
      throw ConfigurationError.invalidValue(
        path: "\(location).path",
        reason: "Provide an absolute path or a path starting with ~."
      )
    }

    let warning = warningThreshold ?? 20
    let critical = criticalThreshold ?? 10
    guard (0...100).contains(warning), (0...100).contains(critical), critical < warning else {
      throw ConfigurationError.invalidValue(
        path: location,
        reason:
          "Free-space thresholds must be between 0 and 100, with criticalThreshold below warningThreshold."
      )
    }

    try symbols?.validate(path: "\(location).symbols")
    try tints?.validate(path: "\(location).tints")
  }
}

struct DiskTints: Codable, Equatable, Sendable {
  var normal: String?
  var warning: String?
  var critical: String?
  var unavailable: String?

  func validate(path: String) throws {
    for (key, tint) in [
      ("normal", normal), ("warning", warning), ("critical", critical),
      ("unavailable", unavailable),
    ] {
      try ItemStyle.validateColor(tint, path: "\(path).\(key)")
    }
  }
}
