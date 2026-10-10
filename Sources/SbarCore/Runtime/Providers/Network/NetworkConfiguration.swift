import Foundation

struct NetworkConfiguration: Codable, Equatable, Sendable {
  var interface: NetworkConnection?
  var symbols: NetworkSymbols?
  var tints: [String: String]?
  var showSymbol: Bool?
  var hideWhenDisconnected: Bool?

  func validate(path: String) throws {
    if interface == .offline {
      throw ConfigurationError.invalidValue(
        path: "\(path).interface",
        reason: "Select a connected interface type."
      )
    }

    try symbols?.validate(path: "\(path).symbols")

    for (key, value) in tints ?? [:] {
      guard NetworkConnection(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: "\(path).tints.\(key)",
          reason: "Unknown network connection type."
        )
      }

      try ItemStyle.validateColor(value, path: "\(path).tints.\(key)")
    }
  }
}

struct NetworkSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, wifi, ethernet, cellular, other, offline
  }

  var font: String?
  var size: Double?
  var wifi: WidgetSymbol?
  var ethernet: WidgetSymbol?
  var cellular: WidgetSymbol?
  var other: WidgetSymbol?
  var offline: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)

    for (key, symbol) in [
      ("wifi", wifi), ("ethernet", ethernet), ("cellular", cellular),
      ("other", other), ("offline", offline),
    ] {
      try symbol?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(_ connection: NetworkConnection) -> ItemSymbol? {
    let symbol: WidgetSymbol?

    switch connection {
    case .wifi: symbol = wifi
    case .ethernet: symbol = ethernet
    case .cellular: symbol = cellular
    case .other: symbol = other
    case .offline: symbol = offline
    }

    return symbol?.resolve(font: font, size: size)
  }
}

extension NetworkSymbols {
  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    let supported = Set(CodingKeys.allCases.map(\.rawValue))
    guard Set(values.keys).isSubset(of: supported) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown network symbol key.")
      )
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    wifi = try container.decodeIfPresent(WidgetSymbol.self, forKey: .wifi)
    ethernet = try container.decodeIfPresent(WidgetSymbol.self, forKey: .ethernet)
    cellular = try container.decodeIfPresent(WidgetSymbol.self, forKey: .cellular)
    other = try container.decodeIfPresent(WidgetSymbol.self, forKey: .other)
    offline = try container.decodeIfPresent(WidgetSymbol.self, forKey: .offline)
  }
}
