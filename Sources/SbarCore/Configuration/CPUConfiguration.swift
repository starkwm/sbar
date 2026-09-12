import Foundation

struct CPUConfiguration: Codable, Equatable, Sendable {
  var symbols: CPUSymbols?
  var tints: CPUTints?
  var showSymbol: Bool?
  var warningThreshold: Int?
  var highThreshold: Int?
  var smoothingSamples: Int?

  func validate(path: String) throws {
    let warning = warningThreshold ?? 60
    let high = highThreshold ?? 85
    guard (0...100).contains(warning), (0...100).contains(high), warning < high else {
      throw ConfigurationError.invalidValue(
        path: path,
        reason:
          "CPU thresholds must be between 0 and 100, with warningThreshold below highThreshold."
      )
    }
    if let smoothingSamples, !(1...30).contains(smoothingSamples) {
      throw ConfigurationError.invalidValue(
        path: "\(path).smoothingSamples",
        reason: "Must be between 1 and 30."
      )
    }
    try symbols?.validate(path: "\(path).symbols")
    try tints?.validate(path: "\(path).tints")
  }
}

struct CPUSymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var low: WidgetSymbol?
  var medium: WidgetSymbol?
  var high: WidgetSymbol?
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
    for (key, symbol) in [
      ("low", low), ("medium", medium), ("high", high), ("unavailable", unavailable),
    ] {
      try symbol?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}

struct CPUTints: Codable, Equatable, Sendable {
  var low: String?
  var medium: String?
  var high: String?
  var unavailable: String?

  func validate(path: String) throws {
    for (key, color) in [
      ("low", low), ("medium", medium), ("high", high), ("unavailable", unavailable),
    ] {
      try ItemStyle.validateColor(color, path: "\(path).\(key)")
    }
  }
}
