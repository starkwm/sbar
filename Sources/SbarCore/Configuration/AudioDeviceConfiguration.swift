import Foundation

struct AudioDeviceConfiguration: Codable, Equatable, Sendable {
  var device: AudioDeviceKind?
  var symbols: AudioDeviceSymbols?
  var tints: [String: String]?
  var showSymbol: Bool?
  var hideWhenDisconnected: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    for (key, value) in tints ?? [:] {
      guard AudioDeviceStatus(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: "\(path).tints.\(key)",
          reason: "Unknown audio device status."
        )
      }
      try ItemStyle.validateColor(value, path: "\(path).tints.\(key)")
    }
  }
}

struct AudioDeviceSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, output, input, disconnected, unavailable
  }

  var font: String?
  var size: Double?
  var output: WidgetSymbol?
  var input: WidgetSymbol?
  var disconnected: WidgetSymbol?
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
      ("output", output), ("input", input), ("disconnected", disconnected),
      ("unavailable", unavailable),
    ] {
      try symbol?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(_ status: AudioDeviceStatus, device: AudioDeviceKind) -> ItemSymbol? {
    let symbol: WidgetSymbol?
    switch status {
    case .available: symbol = device == .input ? input : output
    case .disconnected: symbol = disconnected
    case .unavailable: symbol = unavailable
    }
    return symbol?.resolve(font: font, size: size)
  }
}

extension AudioDeviceSymbols {
  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    guard Set(values.keys).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown audio device symbol key.")
      )
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    output = try container.decodeIfPresent(WidgetSymbol.self, forKey: .output)
    input = try container.decodeIfPresent(WidgetSymbol.self, forKey: .input)
    disconnected = try container.decodeIfPresent(WidgetSymbol.self, forKey: .disconnected)
    unavailable = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unavailable)
  }
}
