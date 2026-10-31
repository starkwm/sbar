import Foundation

struct RemindersConfiguration: Codable, Equatable, Sendable {
  var listIds: [String]?
  var lookaheadDays: Int?
  var includeUndated: Bool?
  var timeFormat: String?
  var symbols: RemindersSymbols?
  var tints: [String: String]?
  var showSymbol: Bool?
  var hideWhenEmpty: Bool?

  var resolvedLookaheadDays: Int { lookaheadDays ?? 7 }

  func validate(path: String) throws {
    if let listIds,
      listIds.isEmpty || Set(listIds).count != listIds.count
        || listIds.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    {
      throw ConfigurationError.invalidValue(
        path: "\(path).listIds",
        reason: "Use unique, nonblank list IDs, or omit listIds for all lists."
      )
    }
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
      guard RemindersStatus(rawValue: key) != nil else {
        throw ConfigurationError.invalidValue(
          path: "\(path).tints.\(key)",
          reason: "Unknown reminders status."
        )
      }
      try ItemStyle.validateColor(value, path: "\(path).tints.\(key)")
    }
  }
}

struct RemindersSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, upcoming, overdue, dueToday, undated, empty, unauthorized, unavailable, loading
  }

  var font: String?
  var size: Double?
  var upcoming: WidgetSymbol?
  var overdue: WidgetSymbol?
  var dueToday: WidgetSymbol?
  var undated: WidgetSymbol?
  var empty: WidgetSymbol?
  var unauthorized: WidgetSymbol?
  var unavailable: WidgetSymbol?
  var loading: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)

    for (key, symbol) in [
      ("upcoming", upcoming), ("overdue", overdue), ("dueToday", dueToday), ("undated", undated),
      ("empty", empty),
      ("unauthorized", unauthorized), ("unavailable", unavailable), ("loading", loading),
    ] {
      try symbol?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(_ status: RemindersStatus) -> ItemSymbol? {
    let symbol: WidgetSymbol?

    switch status {
    case .upcoming: symbol = upcoming
    case .overdue: symbol = overdue
    case .dueToday: symbol = dueToday
    case .undated: symbol = undated
    case .empty: symbol = empty
    case .unauthorized: symbol = unauthorized
    case .unavailable: symbol = unavailable
    case .loading: symbol = loading
    }

    return symbol?.resolve(font: font, size: size)
  }
}

extension RemindersSymbols {
  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    guard Set(values.keys).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown reminders symbol key.")
      )
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    upcoming = try container.decodeIfPresent(WidgetSymbol.self, forKey: .upcoming)
    dueToday = try container.decodeIfPresent(WidgetSymbol.self, forKey: .dueToday)
    undated = try container.decodeIfPresent(WidgetSymbol.self, forKey: .undated)
    overdue = try container.decodeIfPresent(WidgetSymbol.self, forKey: .overdue)
    empty = try container.decodeIfPresent(WidgetSymbol.self, forKey: .empty)
    unauthorized = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unauthorized)
    unavailable = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unavailable)
    loading = try container.decodeIfPresent(WidgetSymbol.self, forKey: .loading)
  }
}
