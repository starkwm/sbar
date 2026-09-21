enum WidgetState: Equatable, Sendable {
  case yabai(YabaiState)
  case aerospace(AerospaceState)
  case spaces(SpacesState)
  case media(MediaState)
  case throughput(ThroughputState)
  case disk(DiskState)
  case memory(MemoryState)
  case cpu(CPUState)
  case bluetooth(BluetoothState)
  case audioDevice(AudioDeviceState)
  case weather(WeatherState)
  case mail(MailState)
  case vpn(VPNState)
  case network(NetworkConnection)
  case battery(percentage: Int?, charging: Bool, pluggedIn: Bool)
  case volume(percentage: Int?, muted: Bool, available: Bool)

  var text: String {
    switch self {
    case .yabai(let state):
      state.text
    case .aerospace(let state):
      state.text
    case .spaces(let state):
      state.text
    case .media(let state):
      state.text
    case .throughput(let state):
      state.text
    case .disk(let state):
      state.text
    case .memory(let state):
      state.text
    case .cpu(let state):
      state.text
    case .bluetooth(let state):
      state.text
    case .audioDevice(let state):
      state.text
    case .weather(let state):
      state.text
    case .mail(let state):
      state.text
    case .vpn(let state):
      state.text
    case .network(let connection):
      connection.text
    case .battery(let percentage, let charging, _):
      percentage.map { "\(charging ? "⚡ " : "")\($0)%" } ?? "AC power"
    case .volume(let percentage, let muted, let available):
      !available
        ? "No output" : muted ? "Muted" : percentage.map { "Volume \($0)%" } ?? "Fixed volume"
    }
  }

  func presentation(for item: Item, displayUUID: String? = nil) -> WidgetPresentation {
    switch self {
    case .yabai(let state):
      return state.presentation(for: item, displayUUID: displayUUID)
    case .aerospace(let state):
      return state.presentation(for: item, displayUUID: displayUUID)
    case .spaces(let state):
      return state.presentation(for: item, displayUUID: displayUUID)
    case .media(let state):
      return state.presentation(for: item)
    case .throughput(let state):
      return state.presentation(for: item)
    case .disk(let state):
      return state.presentation(for: item)
    case .memory(let state):
      return state.presentation(for: item)
    case .cpu(let state):
      return state.presentation(for: item)
    case .bluetooth(let state):
      return state.presentation(for: item)
    case .audioDevice(let state):
      return state.presentation(for: item)
    case .weather(let state):
      return state.presentation(for: item)
    case .mail(let state):
      return state.presentation(for: item)
    case .vpn(let state):
      return state.presentation(for: item)
    case .network(let connection):
      let settings = item.network ?? NetworkConfiguration()
      let state = settings.interface.map { $0 == connection ? connection : .offline } ?? connection
      let label =
        settings.interface.map {
          "\($0 == .wifi ? "Wi-Fi" : $0.rawValue.capitalized) \(state == .offline ? "disconnected" : "connected")"
        } ?? state.text
      let symbol =
        item.symbol ?? settings.symbols?.resolve(state)
        ?? (state == .offline && settings.interface == .wifi ? "wifi.slash" : state.defaultSymbol)

      return WidgetPresentation(
        text: label,
        symbol: settings.showSymbol == false ? nil : symbol,
        tint: settings.tints?[state.rawValue],
        hidden: state == .offline && settings.hideWhenDisconnected == true,
        accessibilityLabel: label
      )
    case .battery(let percentage, let charging, let pluggedIn):
      let settings = item.battery ?? BatteryConfiguration()
      let level = min(100, max(0, percentage ?? 100))
      let index = Int((Double(level) / 25).rounded())
      let batterySymbol: ItemSymbol

      if let symbols = settings.symbols, let levels = symbols.levels, levels.count == 5,
        let resolved = symbols.resolve(levels[index])
      {
        batterySymbol = resolved
      } else {
        batterySymbol = .system("battery.\(index * 25)percent")
      }

      let chargingSymbol: ItemSymbol?

      if let symbols = settings.symbols, let levels = symbols.chargingLevels, levels.count == 5 {
        chargingSymbol = symbols.resolve(levels[index])
      } else {
        chargingSymbol = nil
      }

      let symbol =
        charging
        ? (chargingSymbol ?? settings.symbols?.resolve(settings.symbols?.charging)
          ?? "battery.100percent.bolt")
        : pluggedIn
          ? (settings.symbols?.resolve(settings.symbols?.pluggedIn)
            ?? "powerplug") : batterySymbol
      let tint =
        charging
        ? settings.tints?.charging
        : pluggedIn
          ? settings.tints?.pluggedIn
          : level <= (settings.lowThreshold ?? 20) ? settings.tints?.low : nil
      let label =
        percentage.map {
          "\($0) percent, \(charging ? "charging" : pluggedIn ? "plugged in" : "on battery")"
        } ?? "AC power"

      return WidgetPresentation(
        text: percentage.map { "\($0)%" } ?? "AC power",
        symbol: settings.showSymbol == false ? nil : item.symbol ?? symbol,
        tint: tint,
        accessibilityLabel: label
      )
    case .volume(let percentage, let muted, let available):
      let settings = item.volume ?? VolumeConfiguration()
      let symbol: ItemSymbol
      let tint: String?

      if !available {
        symbol = settings.symbols?.resolve(settings.symbols?.unavailable) ?? "speaker.slash"
        tint = settings.tints?.unavailable
      } else if muted {
        symbol = settings.symbols?.resolve(settings.symbols?.muted) ?? "speaker.slash.fill"
        tint = settings.tints?.muted
      } else if let percentage {
        let level = min(100, max(0, percentage))
        let index = level == 0 ? 0 : level <= 33 ? 1 : level <= 66 ? 2 : 3

        if let symbols = settings.symbols, let levels = symbols.levels, levels.count == 4,
          let resolved = symbols.resolve(levels[index])
        {
          symbol = resolved
        } else {
          symbol = .system(
            [
              "speaker.fill", "speaker.wave.1.fill", "speaker.wave.2.fill", "speaker.wave.3.fill",
            ][index]
          )
        }

        tint = nil
      } else {
        symbol = settings.symbols?.resolve(settings.symbols?.fixed) ?? "speaker.wave.3.fill"
        tint = settings.tints?.fixed
      }

      return WidgetPresentation(
        text: text,
        symbol: settings.showSymbol == false ? nil : item.symbol ?? symbol,
        tint: tint,
        accessibilityLabel: text
      )
    }
  }
}

struct WidgetPresentation: Equatable {
  var text: String
  var symbol: ItemSymbol?
  var tint: String?
  var hidden = false
  var segments: [WidgetSegment] = []
  var accessibilityLabel: String
  var segmentSpacing: Double = 4
}

struct WidgetSegment: Equatable {
  var text: String
  var symbol: ItemSymbol?
  var tint: String? = nil
  var emphasized = false
}
