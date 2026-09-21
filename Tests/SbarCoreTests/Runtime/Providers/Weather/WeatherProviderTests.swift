import Foundation
import Testing

@testable import SbarCore

@Suite("Weather provider")
@MainActor
struct WeatherProviderTests {
  private static let location = WeatherLocation(latitude: 51.5074, longitude: -0.1278)

  private static func reading(_ temperature: Double = 18.4) -> WeatherReading {
    WeatherReading(
      temperature: temperature,
      apparentTemperature: 17,
      humidity: 80,
      windSpeed: 16.09344,
      weatherCode: 2,
      isDay: true,
      time: Date(timeIntervalSince1970: 1_800_000_000)
    )
  }

  @Test("request uses current conditions with explicit canonical units and a timeout")
  func request() throws {
    let request = try OpenMeteoReader.request(for: Self.location)
    let url = try #require(request.url)

    #expect(url.host == "api.open-meteo.com")
    #expect(url.path == "/v1/forecast")

    let query = Dictionary(
      uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!
        .queryItems!.map { ($0.name, $0.value ?? "") }
    )

    #expect(query["latitude"] == "51.5074")
    #expect(query["longitude"] == "-0.1278")
    #expect(query["temperature_unit"] == "celsius")
    #expect(query["wind_speed_unit"] == "kmh")
    #expect(query["timeformat"] == "unixtime")
    #expect(query["current"]?.contains("weather_code") == true)
    #expect(request.timeoutInterval == 15)
    #expect(throws: ConfigurationError.self) {
      try OpenMeteoReader.request(for: .init(latitude: .nan, longitude: 0))
    }
  }

  @Test("decoding rejects HTTP errors and missing required measurements")
  func decoding() throws {
    let url = try #require(try OpenMeteoReader.request(for: Self.location).url)
    func response(_ status: Int) -> HTTPURLResponse {
      HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
    let json =
      #"{"current":{"time":1800000000,"temperature_2m":0,"apparent_temperature":null,"relative_humidity_2m":80,"wind_speed_10m":16.09344,"weather_code":2,"is_day":0}}"#
    let reading = try OpenMeteoReader.decode(Data(json.utf8), response: response(200))

    #expect(reading.temperature == 0)
    #expect(reading.apparentTemperature == nil)
    #expect(reading.humidity == 80)
    #expect(!reading.isDay)
    #expect(reading.time == Date(timeIntervalSince1970: 1_800_000_000))

    for status in [400, 429, 500] {
      #expect(throws: (any Error).self) {
        try OpenMeteoReader.decode(Data(json.utf8), response: response(status))
      }
    }
    for invalid in [
      "{}", #"{"error":true,"reason":"Invalid coordinates"}"#,
      json.replacingOccurrences(of: #""temperature_2m":0"#, with: #""temperature_2m":null"#),
      json.replacingOccurrences(of: #""is_day":0"#, with: #""is_day":2"#),
      json.replacingOccurrences(
        of: #""relative_humidity_2m":80"#,
        with: #""relative_humidity_2m":101"#
      ),
      json.replacingOccurrences(of: #""wind_speed_10m":16.09344"#, with: #""wind_speed_10m":-1"#),
    ] {
      #expect(throws: (any Error).self) {
        try OpenMeteoReader.decode(Data(invalid.utf8), response: response(200))
      }
    }
  }

  @Test("configuration round trips and validates coordinates, intervals, and item type")
  func configuration() throws {
    let data = Data(
      #"{"id":"weather","type":"weather","weather":{"latitude":51.5074,"longitude":-0.1278,"temperatureUnit":"fahrenheit","windSpeedUnit":"mph"}}"#
        .utf8
    )
    let item = try JSONDecoder().decode(Item.self, from: data)
    try Configuration(bar: .init(), items: .init(right: [item])).validate()

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    #expect(item.weather?.resolvedPollInterval == 900)

    for settings in [
      WeatherConfiguration(latitude: 91, longitude: 0),
      WeatherConfiguration(latitude: 0, longitude: -181),
      WeatherConfiguration(latitude: .nan, longitude: 0),
      WeatherConfiguration(latitude: 0, longitude: .infinity),
      WeatherConfiguration(latitude: 0, longitude: 0, pollInterval: 59),
      WeatherConfiguration(latitude: 0, longitude: 0, pollInterval: 86401),
      WeatherConfiguration(latitude: 0, longitude: 0, pollInterval: .nan),
    ] {
      #expect(throws: ConfigurationError.self) { try settings.validate(path: "weather") }
    }
    for badItem in [
      Item(id: "weather", type: .weather),
      Item(id: "text", type: .text, weather: item.weather),
    ] {
      #expect(throws: ConfigurationError.self) {
        try Configuration(bar: .init(), items: .init(right: [badItem])).validate()
      }
    }
    for coordinates in [(-90.0, -180.0), (90.0, 180.0)] {
      try WeatherConfiguration(latitude: coordinates.0, longitude: coordinates.1)
        .validate(path: "weather")
    }
  }

  @Test("presentation converts units before rounding and maps day, night, and unknown codes")
  func presentation() throws {
    var item = Item(
      id: "weather",
      type: .weather,
      weather: .init(
        latitude: 0,
        longitude: 0,
        temperatureUnit: .fahrenheit,
        windSpeedUnit: .mph
      )
    )
    var state = WeatherState(reading: Self.reading())
    let values = state.textValues(settings: item.weather)

    #expect(values["temperature"] == "65")
    #expect(values["temperatureUnit"] == "°F")
    #expect(values["windSpeed"] == "10")
    #expect(values["windSpeedUnit"] == "mph")
    #expect(values["feelsLike"] == "63")
    #expect(state.presentation(for: item).symbol == .system("cloud.sun.fill"))

    state.reading?.isDay = false

    #expect(state.presentation(for: item).symbol == .system("cloud.moon.fill"))

    for (code, symbol) in [
      (0, "moon.stars.fill"), (45, "cloud.fog.fill"), (65, "cloud.rain.fill"),
      (75, "cloud.snow.fill"), (95, "cloud.bolt.rain.fill"), (999, "questionmark"),
    ] {
      state.reading?.weatherCode = code

      #expect(state.reading?.symbol == symbol)
    }

    item.symbol = .system("star")

    #expect(state.presentation(for: item).symbol == .system("star"))

    item.weather?.showSymbol = false

    #expect(state.presentation(for: item).symbol == nil)

    state.stale = true
    let template = try TextTemplate(
      "{{#available}}{{temperature}}{{temperatureUnit}}{{#stale}} stale{{/stale}}{{/available}}{{^available}}Unavailable{{/available}}",
      fields: TextTemplate.fields(for: .weather),
      allowedValues: TextTemplate.allowedValues(for: .weather)
    )

    #expect(template.render(state.textValues(settings: item.weather)) == "65°F stale")
    #expect(template.render(WeatherState().textValues(settings: nil)) == "Unavailable")
    #expect(WeatherState().presentation(for: item).text == "Weather unavailable")
  }

  @Test("polling retains readings on failure and recovers")
  func polling() async throws {
    var reads = 0
    var states: [WeatherState] = []
    let provider = WeatherProvider { _ in
      reads += 1

      if reads == 1 || reads == 3 { throw URLError(.notConnectedToInternet) }

      return Self.reading(Double(reads))
    }
    defer { provider.stop() }
    provider.configure([Self.location: 0.01]) { _, state in states.append(state) }

    for _ in 0..<100 where states.count < 4 { try await Task.sleep(for: .milliseconds(10)) }

    #expect(states.count >= 4)

    guard states.count >= 4 else { return }

    #expect(states[0].status == "unavailable")
    #expect(states[1].reading?.temperature == 2)
    #expect(states[2].status == "stale")
    #expect(states[2].reading == states[1].reading)
    #expect(states[3].status == "available")
    #expect(states[3].reading?.temperature == 4)

    provider.stop()
    let stopped = reads
    try await Task.sleep(for: .milliseconds(30))

    #expect(reads == stopped)
  }

  @Test("a cancelled request cannot publish into a restarted location")
  func cancellation() async throws {
    var reads = 0
    var temperatures: [Double] = []
    let provider = WeatherProvider { _ in
      reads += 1
      let count = reads
      await Task.detached { try? await Task.sleep(for: .milliseconds(60)) }.value

      return Self.reading(Double(count))
    }
    defer { provider.stop() }
    provider.configure([Self.location: 900]) { _, state in
      temperatures.append(state.reading!.temperature)
    }

    for _ in 0..<100 where reads == 0 { try await Task.sleep(for: .milliseconds(5)) }

    provider.configure([Self.location: 600]) { _, state in
      temperatures.append(state.reading!.temperature)
    }

    for _ in 0..<100 where temperatures.isEmpty { try await Task.sleep(for: .milliseconds(5)) }

    #expect(temperatures == [2])
  }

  @Test("runtime shares requests, preserves snapshots, and clears changed locations")
  func runtime() async throws {
    var reads = 0
    let provider = WeatherProvider { location in
      reads += 1

      return Self.reading(location.latitude)
    }
    let runtime = ProviderRuntime(weather: provider)
    defer { runtime.stop() }
    var first = Item(
      id: "first",
      type: .weather,
      weather: .init(latitude: 10, longitude: 0),
      refresh: .init(mode: .manual)
    )
    var second = Item(
      id: "second",
      type: .weather,
      weather: .init(
        latitude: 10,
        longitude: 0,
        temperatureUnit: .fahrenheit,
        pollInterval: 600
      )
    )
    let disabled = Item(
      id: "disabled",
      type: .weather,
      enabled: false,
      weather: .init(latitude: 10, longitude: 0, pollInterval: 60)
    )
    func configure() {
      runtime.configure(
        Configuration(bar: .init(), items: .init(right: [first, second, disabled]))
      )
    }
    configure()

    for _ in 0..<100 where runtime.weatherStates.isEmpty {
      try await Task.sleep(for: .milliseconds(5))
    }

    #expect(reads == 1)
    #expect(provider.intervals[first.weather!.location] == 600)
    #expect(runtime.presentation(for: first)?.text == "10°C")
    #expect(runtime.presentation(for: second)?.text == "50°F")

    first.text = "{{condition}} {{temperature}}{{temperatureUnit}}"
    configure()
    await Task.yield()

    #expect(reads == 1)
    #expect(runtime.presentation(for: first)?.text == "Partly cloudy 10°C")

    first.weather?.latitude = 20
    configure()

    #expect(runtime.presentation(for: first)?.text == " ")

    for _ in 0..<100 where runtime.weatherStates[first.weather!.location]?.reading == nil {
      try await Task.sleep(for: .milliseconds(5))
    }

    #expect(runtime.presentation(for: first)?.text == "Partly cloudy 20°C")
    #expect(runtime.presentation(for: second)?.text == "50°F")

    second.enabled = false
    configure()

    #expect(provider.intervals.count == 1)
    #expect(provider.intervals[first.weather!.location] == 900)

    runtime.configure(Configuration(bar: .init(), items: .init()))

    #expect(provider.intervals.isEmpty)
    #expect(runtime.weatherStates.isEmpty)
  }
  @Test("manual and event snapshots behave independently of shared polling")
  func snapshots() async throws {
    var reads = 0
    let provider = WeatherProvider { _ in
      reads += 1

      return Self.reading(Double(reads))
    }
    let runtime = ProviderRuntime(weather: provider)
    defer { runtime.stop() }
    let manual = Item(
      id: "manual",
      type: .weather,
      weather: .init(latitude: 0, longitude: 0, pollInterval: 0.01),
      refresh: .init(mode: .manual)
    )
    let event = Item(
      id: "event",
      type: .weather,
      weather: manual.weather,
      refresh: .init(mode: .event)
    )
    let live = Item(id: "live", type: .weather, weather: manual.weather)
    var events: [String] = []
    runtime.onValueChange = { id, _ in events.append(id) }
    runtime.configure(Configuration(bar: .init(), items: .init(right: [manual, event, live])))

    for _ in 0..<100 where reads < 3 { try await Task.sleep(for: .milliseconds(5)) }

    #expect(reads >= 3)
    #expect(runtime.presentation(for: manual)?.text == "1°C")
    #expect(runtime.presentation(for: event)?.text == "\(reads)°C")
    #expect(runtime.presentation(for: live)?.text == "\(reads)°C")
    #expect(runtime.widgetSnapshots[live.id] == nil)
    #expect(Set(events) == ["manual", "event", "live"])

    runtime.trigger(manual.id)

    #expect(runtime.presentation(for: manual)?.text == "\(reads)°C")

    let snapshot = runtime.presentation(for: manual)?.text
    let captured = reads

    for _ in 0..<100 where reads == captured { try await Task.sleep(for: .milliseconds(5)) }

    #expect(runtime.presentation(for: manual)?.text == snapshot)
  }

  @Test("weather symbols inherit glyph settings and preserve precedence and defaults")
  func customSymbols() throws {
    let json =
      #"{"latitude":0,"longitude":0,"symbols":{"font":"Symbols Nerd Font Mono","size":16,"clearDay":"sun.max","clearNight":{"glyph":"☾"},"rain":{"glyph":"R","font":"Other Font","size":20},"unavailable":"wifi.slash","unknown":"questionmark.circle"}}"#
    let settings = try JSONDecoder().decode(WeatherConfiguration.self, from: Data(json.utf8))
    try settings.validate(path: "weather")

    #expect(
      try JSONDecoder().decode(WeatherConfiguration.self, from: JSONEncoder().encode(settings))
        == settings
    )

    var item = Item(id: "weather", type: .weather, weather: settings)
    var state = WeatherState(reading: Self.reading())

    #expect(state.presentation(for: item).symbol == .system("cloud.sun.fill"))

    state.reading?.weatherCode = 0

    #expect(state.presentation(for: item).symbol == .system("sun.max"))

    state.reading?.isDay = false

    #expect(
      state.presentation(for: item).symbol == .glyph("☾", font: "Symbols Nerd Font Mono", size: 16)
    )

    state.reading?.weatherCode = 65
    state.stale = true

    #expect(state.presentation(for: item).symbol == .glyph("R", font: "Other Font", size: 20))

    state.reading?.weatherCode = 999

    #expect(state.presentation(for: item).symbol == .system("questionmark.circle"))

    state.reading = nil

    #expect(state.presentation(for: item).symbol == .system("wifi.slash"))

    item.symbol = .system("star")

    #expect(state.presentation(for: item).symbol == .system("star"))

    item.weather?.showSymbol = false

    #expect(state.presentation(for: item).symbol == nil)
  }

  @Test("weather symbol validation rejects unknown keys and incomplete glyph settings")
  func invalidSymbols() throws {
    for symbols in [
      #"{"rani":"cloud.rain"}"#,
      #"{"rain":{"glyph":"R"}}"#,
      #"{"font":" ","rain":{"glyph":"R"}}"#,
      #"{"size":73}"#,
      #"{"rain":{"glyph":"","font":"Example"}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(WeatherSymbols.self, from: Data(symbols.utf8))
        try settings.validate(path: "weather.symbols")
      }
    }
  }

  @Test("every weather code selects the documented symbol key")
  func symbolConditions() {
    let groups: [(WeatherSymbolCondition, [Int])] = [
      (.clearDay, [0, 1]), (.partlyCloudyDay, [2]), (.overcastDay, [3]),
      (.fog, [45, 48]), (.drizzle, [51, 53, 55]), (.freezingDrizzle, [56, 57]),
      (.rain, [61, 63, 65]), (.freezingRain, [66, 67]), (.snow, [71, 73, 75, 77]),
      (.rainShowers, [80, 81, 82]), (.snowShowers, [85, 86]),
      (.thunderstorm, [95]), (.thunderstormHail, [96, 99]), (.unknown, [999]),
    ]

    for (condition, codes) in groups {
      for code in codes {
        var reading = Self.reading()
        reading.weatherCode = code

        #expect(reading.symbolCondition == condition)

        reading.isDay = false
        let night =
          condition == .clearDay
          ? WeatherSymbolCondition.clearNight
          : condition == .partlyCloudyDay
            ? .partlyCloudyNight
            : condition == .overcastDay ? .overcastNight : condition

        #expect(reading.symbolCondition == night)
      }
    }
  }

  @Test("overcast day and night symbols override the shared fallback")
  func overcastSymbols() throws {
    let json =
      #"{"font":"Example Font","overcast":"cloud","overcastDay":"cloud.sun","overcastNight":{"glyph":"N"}}"#
    var symbols = try JSONDecoder().decode(WeatherSymbols.self, from: Data(json.utf8))
    try symbols.validate(path: "weather.symbols")

    #expect(
      try JSONDecoder().decode(WeatherSymbols.self, from: JSONEncoder().encode(symbols)) == symbols
    )

    var state = WeatherState(reading: Self.reading())
    state.reading?.weatherCode = 3
    var item = Item(
      id: "weather",
      type: .weather,
      weather: .init(latitude: 0, longitude: 0, symbols: symbols)
    )

    #expect(state.presentation(for: item).symbol == .system("cloud.sun"))

    state.reading?.isDay = false

    #expect(state.presentation(for: item).symbol == .glyph("N", font: "Example Font"))

    symbols.overcastNight = nil
    item.weather?.symbols = symbols

    #expect(state.presentation(for: item).symbol == .system("cloud"))

    symbols.overcastDay = nil
    item.weather?.symbols = symbols
    state.reading?.isDay = true

    #expect(state.presentation(for: item).symbol == .system("cloud"))

    item.weather?.symbols = nil

    #expect(state.presentation(for: item).symbol == .system("cloud.fill"))

    for key in ["overcastDay", "overcastNight"] {
      let invalid = "{\"\(key)\":{\"glyph\":\"N\"}}"

      #expect(throws: (any Error).self) {
        let decoded = try JSONDecoder().decode(WeatherSymbols.self, from: Data(invalid.utf8))
        try decoded.validate(path: "weather.symbols")
      }
    }
  }

}
