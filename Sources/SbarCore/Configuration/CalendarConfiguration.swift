import Foundation

struct CalendarConfiguration: Codable, Equatable, Sendable {
  var lookaheadDays: Int?
  var includeAllDay: Bool?
  var timeFormat: String?
  var symbols: CalendarSymbols?
  var tints: [String: String]?
  var showSymbol: Bool?
  var hideWhenEmpty: Bool?

  var resolvedLookaheadDays: Int { lookaheadDays ?? 7 }

  func validate(path: String) throws {
    if let lookaheadDays, !(1...30).contains(lookaheadDays) {
      throw ConfigurationError.invalidValue(
        path: "\(path).lookaheadDays",
        reason: "Must be between 1 and 30."
      )
    }
    if let timeFormat, timeFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw ConfigurationError.invalidValue(
        path: "\(path).timeFormat",
        reason: "Must not be blank."
      )
    }

    try symbols?.validate(path: "\(path).symbols")

    for (key, value) in tints ?? [:] {
      guard CalendarStatus(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: "\(path).tints.\(key)",
          reason: "Unknown calendar status."
        )
      }
      try ItemStyle.validateColor(value, path: "\(path).tints.\(key)")
    }
  }
}

struct CalendarSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, upcoming, ongoing, empty, unauthorized, unavailable, loading
  }

  var font: String?
  var size: Double?
  var upcoming: WidgetSymbol?
  var ongoing: WidgetSymbol?
  var empty: WidgetSymbol?
  var unauthorized: WidgetSymbol?
  var unavailable: WidgetSymbol?
  var loading: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)

    for (key, symbol) in [
      ("upcoming", upcoming), ("ongoing", ongoing), ("empty", empty),
      ("unauthorized", unauthorized), ("unavailable", unavailable), ("loading", loading),
    ] {
      try symbol?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(_ status: CalendarStatus) -> ItemSymbol? {
    let symbol: WidgetSymbol?

    switch status {
    case .upcoming: symbol = upcoming
    case .ongoing: symbol = ongoing
    case .empty: symbol = empty
    case .unauthorized: symbol = unauthorized
    case .unavailable: symbol = unavailable
    case .loading: symbol = loading
    }

    return symbol?.resolve(font: font, size: size)
  }
}

extension CalendarSymbols {
  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    guard Set(values.keys).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown calendar symbol key.")
      )
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    upcoming = try container.decodeIfPresent(WidgetSymbol.self, forKey: .upcoming)
    ongoing = try container.decodeIfPresent(WidgetSymbol.self, forKey: .ongoing)
    empty = try container.decodeIfPresent(WidgetSymbol.self, forKey: .empty)
    unauthorized = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unauthorized)
    unavailable = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unavailable)
    loading = try container.decodeIfPresent(WidgetSymbol.self, forKey: .loading)
  }
}
