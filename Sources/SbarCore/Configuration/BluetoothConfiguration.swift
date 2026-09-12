import Foundation

struct BluetoothConfiguration: Codable, Equatable, Sendable {
  var symbols: BluetoothSymbols?
  var tints: [String: String]?
  var showSymbol: Bool?
  var hideWhenDisconnected: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    for (key, value) in tints ?? [:] {
      guard BluetoothStatus(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: "\(path).tints.\(key)",
          reason: "Unknown Bluetooth status."
        )
      }
      try ItemStyle.validateColor(value, path: "\(path).tints.\(key)")
    }
  }
}

struct BluetoothSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, on, off, connected, unauthorized, unavailable
  }

  var font: String?
  var size: Double?
  var on: WidgetSymbol?
  var connected: WidgetSymbol?
  var off: WidgetSymbol?
  var unauthorized: WidgetSymbol?
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
    for status in BluetoothStatus.allCases {
      try symbol(for: status)?.validate(font: font, path: "\(path).\(status.rawValue)")
    }
  }

  func resolve(_ status: BluetoothStatus) -> ItemSymbol? {
    symbol(for: status)?.resolve(font: font, size: size)
  }

  private func symbol(for status: BluetoothStatus) -> WidgetSymbol? {
    switch status {
    case .on: on
    case .connected: connected
    case .off: off
    case .unauthorized: unauthorized
    case .unavailable: unavailable
    }
  }
}

extension BluetoothSymbols {
  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    guard Set(values.keys).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown Bluetooth symbol key.")
      )
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    on = try container.decodeIfPresent(WidgetSymbol.self, forKey: .on)
    connected = try container.decodeIfPresent(WidgetSymbol.self, forKey: .connected)
    off = try container.decodeIfPresent(WidgetSymbol.self, forKey: .off)
    unauthorized = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unauthorized)
    unavailable = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unavailable)
  }
}
