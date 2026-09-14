import Foundation

struct WeatherSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, clearDay, clearNight, partlyCloudyDay, partlyCloudyNight, overcast, fog,
      drizzle, freezingDrizzle, rain, freezingRain, snow, rainShowers, snowShowers, thunderstorm,
      thunderstormHail, unknown, unavailable
  }

  var font: String?
  var size: Double?
  var clearDay: WidgetSymbol?
  var clearNight: WidgetSymbol?
  var partlyCloudyDay: WidgetSymbol?
  var partlyCloudyNight: WidgetSymbol?
  var overcast: WidgetSymbol?
  var fog: WidgetSymbol?
  var drizzle: WidgetSymbol?
  var freezingDrizzle: WidgetSymbol?
  var rain: WidgetSymbol?
  var freezingRain: WidgetSymbol?
  var snow: WidgetSymbol?
  var rainShowers: WidgetSymbol?
  var snowShowers: WidgetSymbol?
  var thunderstorm: WidgetSymbol?
  var thunderstormHail: WidgetSymbol?
  var unknown: WidgetSymbol?
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
    for status in WeatherSymbolCondition.allCases {
      try symbol(for: status)?.validate(font: font, path: "\(path).\(status.rawValue)")
    }
  }

  func resolve(_ status: WeatherSymbolCondition) -> ItemSymbol? {
    symbol(for: status)?.resolve(font: font, size: size)
  }

  private func symbol(for status: WeatherSymbolCondition) -> WidgetSymbol? {
    switch status {
    case .clearDay: clearDay
    case .clearNight: clearNight
    case .partlyCloudyDay: partlyCloudyDay
    case .partlyCloudyNight: partlyCloudyNight
    case .overcast: overcast
    case .fog: fog
    case .drizzle: drizzle
    case .freezingDrizzle: freezingDrizzle
    case .rain: rain
    case .freezingRain: freezingRain
    case .snow: snow
    case .rainShowers: rainShowers
    case .snowShowers: snowShowers
    case .thunderstorm: thunderstorm
    case .thunderstormHail: thunderstormHail
    case .unknown: unknown
    case .unavailable: unavailable
    }
  }
}

extension WeatherSymbols {
  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    guard Set(values.keys).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown weather symbol key.")
      )
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    clearDay = try container.decodeIfPresent(WidgetSymbol.self, forKey: .clearDay)
    clearNight = try container.decodeIfPresent(WidgetSymbol.self, forKey: .clearNight)
    partlyCloudyDay = try container.decodeIfPresent(WidgetSymbol.self, forKey: .partlyCloudyDay)
    partlyCloudyNight = try container.decodeIfPresent(WidgetSymbol.self, forKey: .partlyCloudyNight)
    overcast = try container.decodeIfPresent(WidgetSymbol.self, forKey: .overcast)
    fog = try container.decodeIfPresent(WidgetSymbol.self, forKey: .fog)
    drizzle = try container.decodeIfPresent(WidgetSymbol.self, forKey: .drizzle)
    freezingDrizzle = try container.decodeIfPresent(WidgetSymbol.self, forKey: .freezingDrizzle)
    rain = try container.decodeIfPresent(WidgetSymbol.self, forKey: .rain)
    freezingRain = try container.decodeIfPresent(WidgetSymbol.self, forKey: .freezingRain)
    snow = try container.decodeIfPresent(WidgetSymbol.self, forKey: .snow)
    rainShowers = try container.decodeIfPresent(WidgetSymbol.self, forKey: .rainShowers)
    snowShowers = try container.decodeIfPresent(WidgetSymbol.self, forKey: .snowShowers)
    thunderstorm = try container.decodeIfPresent(WidgetSymbol.self, forKey: .thunderstorm)
    thunderstormHail = try container.decodeIfPresent(WidgetSymbol.self, forKey: .thunderstormHail)
    unknown = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unknown)
    unavailable = try container.decodeIfPresent(WidgetSymbol.self, forKey: .unavailable)
  }
}

enum WeatherSymbolCondition: String, CaseIterable, Sendable {
  case clearDay, clearNight, partlyCloudyDay, partlyCloudyNight, overcast, fog, drizzle,
    freezingDrizzle, rain, freezingRain, snow, rainShowers, snowShowers, thunderstorm,
    thunderstormHail, unknown, unavailable
}
