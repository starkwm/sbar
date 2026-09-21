import Foundation

@MainActor
final class WeatherProvider {
  private(set) var intervals: [WeatherLocation: Double] = [:]

  private let read: @MainActor @Sendable (WeatherLocation) async throws -> WeatherReading
  private var tasks: [WeatherLocation: Task<Void, Never>] = [:]
  private var states: [WeatherLocation: WeatherState] = [:]

  init(
    read: @escaping @MainActor @Sendable (WeatherLocation) async throws -> WeatherReading =
      OpenMeteoReader.read
  ) {
    self.read = read
  }

  func configure(
    _ requested: [WeatherLocation: Double],
    update: @escaping @MainActor (WeatherLocation, WeatherState) -> Void
  ) {
    for location in tasks.keys where requested[location] != intervals[location] {
      tasks.removeValue(forKey: location)?.cancel()
    }

    states = states.filter { requested[$0.key] != nil }
    intervals = requested

    for (location, interval) in requested where tasks[location] == nil {
      let read = read
      tasks[location] = Task { [weak self] in
        while !Task.isCancelled {
          let state: WeatherState

          do {
            let reading = try await read(location)
            state = WeatherState(reading: reading)
          } catch {
            guard !Task.isCancelled else { return }

            state = WeatherState(reading: self?.states[location]?.reading, stale: true)
          }

          guard !Task.isCancelled else { return }

          self?.states[location] = state
          update(location, state)

          do { try await Task.sleep(for: .seconds(interval)) } catch { return }
        }
      }
    }
  }

  func stop() {
    for task in tasks.values { task.cancel() }

    tasks = [:]
    intervals = [:]
    states = [:]
  }
}

enum OpenMeteoReader {
  static func request(for location: WeatherLocation) throws -> URLRequest {
    try WeatherConfiguration(latitude: location.latitude, longitude: location.longitude)
      .validate(path: "weather")
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
    components.queryItems = [
      URLQueryItem(name: "latitude", value: String(location.latitude)),
      URLQueryItem(name: "longitude", value: String(location.longitude)),
      URLQueryItem(
        name: "current",
        value:
          "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
      ),
      URLQueryItem(name: "temperature_unit", value: "celsius"),
      URLQueryItem(name: "wind_speed_unit", value: "kmh"),
      URLQueryItem(name: "timeformat", value: "unixtime"),
    ]
    guard let url = components.url else { throw MessageError.message("Invalid weather URL.") }

    return URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
  }

  static func read(_ location: WeatherLocation) async throws -> WeatherReading {
    let (data, response) = try await URLSession.shared.data(for: request(for: location))

    return try decode(data, response: response)
  }

  static func decode(_ data: Data, response: URLResponse) throws -> WeatherReading {
    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
    else { throw MessageError.message("Weather request failed.") }

    let current = try JSONDecoder().decode(OpenMeteoResponse.self, from: data).current
    guard current.time.isFinite, current.temperature.isFinite,
      current.isDay == 0 || current.isDay == 1,
      current.apparentTemperature.map(\.isFinite) ?? true,
      current.humidity.map({ $0.isFinite && (0...100).contains($0) }) ?? true,
      current.windSpeed.map({ $0.isFinite && $0 >= 0 }) ?? true
    else { throw MessageError.message("Invalid weather data.") }

    return WeatherReading(
      temperature: current.temperature,
      apparentTemperature: current.apparentTemperature,
      humidity: current.humidity,
      windSpeed: current.windSpeed,
      weatherCode: current.weatherCode,
      isDay: current.isDay == 1,
      time: Date(timeIntervalSince1970: current.time)
    )
  }
}

private struct OpenMeteoResponse: Decodable {
  struct Current: Decodable {
    enum CodingKeys: String, CodingKey {
      case time
      case temperature = "temperature_2m"
      case apparentTemperature = "apparent_temperature"
      case humidity = "relative_humidity_2m"
      case windSpeed = "wind_speed_10m"
      case weatherCode = "weather_code"
      case isDay = "is_day"
    }

    var time: Double
    var temperature: Double
    var apparentTemperature: Double?
    var humidity: Double?
    var windSpeed: Double?
    var weatherCode: Int
    var isDay: Int
  }

  var current: Current
}
