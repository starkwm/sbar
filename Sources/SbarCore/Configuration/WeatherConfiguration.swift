import Foundation

struct WeatherConfiguration: Codable, Equatable, Sendable {
  enum TemperatureUnit: String, Codable, Sendable {
    case celsius, fahrenheit
  }

  enum WindSpeedUnit: String, Codable, Sendable {
    case kmh, mph, ms, kn
  }

  var latitude: Double
  var longitude: Double
  var temperatureUnit: TemperatureUnit?
  var windSpeedUnit: WindSpeedUnit?
  var pollInterval: Double?
  var showSymbol: Bool?

  var location: WeatherLocation { WeatherLocation(latitude: latitude, longitude: longitude) }
  var resolvedPollInterval: Double { pollInterval ?? 900 }

  func validate(path: String) throws {
    try ItemStyle.validateNumber(latitude, range: -90...90, path: "\(path).latitude")
    try ItemStyle.validateNumber(longitude, range: -180...180, path: "\(path).longitude")
    try ItemStyle.validateNumber(pollInterval, range: 60...86400, path: "\(path).pollInterval")
  }
}

struct WeatherLocation: Hashable, Sendable {
  var latitude: Double
  var longitude: Double
}
