import Foundation

struct VPNConfiguration: Codable, Equatable, Sendable {
  var symbols: VPNSymbols?
  var tints: [String: String]?
  var showSymbol: Bool?
  var hideWhenDisconnected: Bool?

  func validate(path: String) throws {
    try symbols?.validate(path: "\(path).symbols")
    for (key, value) in tints ?? [:] {
      guard VPNStatus(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: "\(path).tints.\(key)",
          reason: "Unknown VPN status."
        )
      }
      try ItemStyle.validateColor(value, path: "\(path).tints.\(key)")
    }
  }
}

struct VPNSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, connecting, connected, disconnecting, disconnected, unavailable
  }

  var font: String?
  var size: Double?
  var connecting: WidgetSymbol?
  var connected: WidgetSymbol?
  var disconnecting: WidgetSymbol?
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
    for status in VPNStatus.allCases {
      try symbol(for: status)?.validate(font: font, path: "\(path).\(status.rawValue)")
    }
  }

  func resolve(_ status: VPNStatus) -> ItemSymbol? {
    symbol(for: status)?.resolve(font: font, size: size)
  }

  private func symbol(for status: VPNStatus) -> WidgetSymbol? {
    switch status {
    case .connecting: connecting
    case .connected: connected
    case .disconnecting: disconnecting
    case .disconnected: disconnected
    case .unavailable: unavailable
    }
  }
}

extension VPNSymbols {
  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    guard Set(values.keys).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown VPN symbol key.")
      )
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    connecting = try container.decodeIfPresent(WidgetSymbol.self, forKey: .connecting)
    connected = try container.decodeIfPresent(WidgetSymbol.self, forKey: .connected)
    disconnecting = try container.decodeIfPresent(WidgetSymbol.self, forKey: .disconnecting)
    disconnected = try container.decodeIfPresent(WidgetSymbol.self, forKey: .disconnected)
    unavailable = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unavailable)
  }
}
