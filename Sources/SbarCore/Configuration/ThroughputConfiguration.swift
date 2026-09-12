import Foundation

struct ThroughputConfiguration: Codable, Equatable, Sendable {
  var interfaces: [String]?
  var unit: ThroughputUnit?
  var symbols: ThroughputSymbols?
  var showSymbol: Bool?
  var smoothingSamples: Int?

  func validate(path: String) throws {
    if let interfaces,
      interfaces.isEmpty || Set(interfaces).count != interfaces.count
        || interfaces.contains(where: {
          $0.trimmingCharacters(in: .whitespacesAndNewlines) != $0 || $0.isEmpty
        })
    {
      throw ConfigurationError.invalidValue(
        path: "\(path).interfaces",
        reason:
          "Provide unique, nonblank interface names or omit interfaces for all non-loopback interfaces."
      )
    }
    if let smoothingSamples, !(1...30).contains(smoothingSamples) {
      throw ConfigurationError.invalidValue(
        path: "\(path).smoothingSamples",
        reason: "Must be between 1 and 30."
      )
    }
    try symbols?.validate(path: "\(path).symbols")
  }
}

enum ThroughputUnit: String, Codable, Sendable {
  case bytes, bits
}

struct ThroughputSymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var download: WidgetSymbol?
  var upload: WidgetSymbol?
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
    for (key, symbol) in [("download", download), ("upload", upload), ("unavailable", unavailable)]
    {
      try symbol?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}
