import Foundation

struct WeatherState: Equatable, Sendable {
  private static func number(_ value: Double) -> String {
    // Avoid integer conversion traps on malformed but finite API numbers.
    value.rounded().formatted(.number.precision(.fractionLength(0)).grouping(.never))
  }

  var reading: WeatherReading?
  var stale = false

  var status: String { reading == nil ? "unavailable" : stale ? "stale" : "available" }
  var text: String { textValues(settings: nil)["value"] ?? "Weather unavailable" }

  func textValues(settings: WeatherConfiguration?) -> [String: String] {
    var values = [
      "available": String(reading != nil), "stale": String(reading != nil && stale),
      "status": status, "value": "Weather unavailable",
    ]
    guard let reading else { return values }

    let fahrenheit = settings?.temperatureUnit == .fahrenheit
    func temperature(_ value: Double) -> String {
      Self.number(fahrenheit ? value * 1.8 + 32 : value)
    }
    let unit = fahrenheit ? "°F" : "°C"
    let windUnit: String
    let windFactor: Double

    switch settings?.windSpeedUnit ?? .kmh {
    case .kmh: (windUnit, windFactor) = ("km/h", 1)
    case .mph: (windUnit, windFactor) = ("mph", 1 / 1.609344)
    case .ms: (windUnit, windFactor) = ("m/s", 1 / 3.6)
    case .kn: (windUnit, windFactor) = ("kn", 1 / 1.852)
    }

    values.merge([
      "temperature": temperature(reading.temperature), "temperatureUnit": unit,
      "feelsLike": reading.apparentTemperature.map(temperature) ?? "",
      "humidity": reading.humidity.map(Self.number) ?? "",
      "windSpeed": reading.windSpeed.map { Self.number($0 * windFactor) } ?? "",
      "windSpeedUnit": windUnit, "condition": reading.condition,
      "weatherCode": String(reading.weatherCode), "isDay": String(reading.isDay),
      "updatedAt": reading.time.ISO8601Format(),
      "value": "\(temperature(reading.temperature))\(unit)",
    ]) { _, new in new }

    return values
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let values = textValues(settings: item.weather)
    let text = values["value"] ?? "Weather unavailable"

    return WidgetPresentation(
      text: text,
      symbol: item.weather?.showSymbol == false
        ? nil
        : item.symbol
          ?? item.weather?.symbols?.resolve(reading?.symbolCondition ?? .unavailable)
          ?? .system(reading?.symbol ?? "questionmark"),
      accessibilityLabel: reading.map {
        "\($0.condition), \(text)\(stale ? ", stale" : ""), weather data by Open-Meteo"
      } ?? text
    )
  }
}

struct WeatherReading: Equatable, Sendable {
  var temperature: Double
  var apparentTemperature: Double?
  var humidity: Double?
  var windSpeed: Double?
  var weatherCode: Int
  var isDay: Bool
  var time: Date

  var condition: String {
    switch weatherCode {
    case 0: "Clear sky"
    case 1: "Mainly clear"
    case 2: "Partly cloudy"
    case 3: "Overcast"
    case 45, 48: "Fog"
    case 51, 53, 55: "Drizzle"
    case 56, 57: "Freezing drizzle"
    case 61, 63, 65: "Rain"
    case 66, 67: "Freezing rain"
    case 71, 73, 75, 77: "Snow"
    case 80, 81, 82: "Rain showers"
    case 85, 86: "Snow showers"
    case 95: "Thunderstorm"
    case 96, 99: "Thunderstorm with hail"
    default: "Unknown conditions"
    }
  }

  var symbolCondition: WeatherSymbolCondition {
    switch weatherCode {
    case 0, 1: isDay ? .clearDay : .clearNight
    case 2: isDay ? .partlyCloudyDay : .partlyCloudyNight
    case 3: isDay ? .overcastDay : .overcastNight
    case 45, 48: .fog
    case 51, 53, 55: .drizzle
    case 56, 57: .freezingDrizzle
    case 61, 63, 65: .rain
    case 66, 67: .freezingRain
    case 71, 73, 75, 77: .snow
    case 80, 81, 82: .rainShowers
    case 85, 86: .snowShowers
    case 95: .thunderstorm
    case 96, 99: .thunderstormHail
    default: .unknown
    }
  }

  var symbol: String {
    switch weatherCode {
    case 0, 1: isDay ? "sun.max.fill" : "moon.stars.fill"
    case 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    case 3: "cloud.fill"
    case 45, 48: "cloud.fog.fill"
    case 51, 53, 55: "cloud.drizzle.fill"
    case 56, 57, 66, 67: "cloud.sleet.fill"
    case 61, 63, 65, 80, 81, 82: "cloud.rain.fill"
    case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
    case 95: "cloud.bolt.rain.fill"
    case 96, 99: "cloud.hail.fill"
    default: "questionmark"
    }
  }
}
