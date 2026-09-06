enum WidgetState: Equatable, Sendable {
  case battery(percentage: Int?, charging: Bool, pluggedIn: Bool)
  case wifi(connected: Bool)

  var text: String {
    switch self {
    case .battery(let percentage, let charging, _):
      percentage.map { "\(charging ? "⚡ " : "")\($0)%" } ?? "AC power"
    case .wifi(let connected):
      connected ? "Wi-Fi connected" : "Wi-Fi disconnected"
    }
  }

  func presentation(for item: Item) -> WidgetPresentation {
    switch self {
    case .battery(let percentage, let charging, let pluggedIn):
      guard let settings = item.battery else {
        return WidgetPresentation(text: text, symbol: item.symbol, accessibilityLabel: text)
      }
      let level = min(100, max(0, percentage ?? 100))
      let index = Int((Double(level) / 25).rounded())
      let batterySymbol: ItemSymbol
      if let symbols = settings.symbols, let levels = symbols.levels, levels.count == 5,
        let resolved = symbols.resolve(levels[index])
      {
        batterySymbol = resolved
      } else if let symbols = settings.levelSymbols, symbols.count == 5 {
        batterySymbol = symbols[index]
      } else {
        batterySymbol = .system("battery.\(index * 25)percent")
      }
      let symbol =
        charging
        ? (settings.symbols?.resolve(settings.symbols?.charging) ?? settings.chargingSymbol
          ?? "battery.100percent.bolt")
        : pluggedIn
          ? (settings.symbols?.resolve(settings.symbols?.pluggedIn) ?? settings.pluggedInSymbol
            ?? "powerplug") : batterySymbol
      let tint =
        charging
        ? settings.tints?.charging ?? settings.chargingTint
        : pluggedIn
          ? settings.tints?.pluggedIn ?? settings.pluggedInTint
          : level <= (settings.lowThreshold ?? 20) ? settings.tints?.low ?? settings.lowTint : nil
      let label =
        percentage.map {
          "\($0) percent, \(charging ? "charging" : pluggedIn ? "plugged in" : "on battery")"
        } ?? "AC power"
      return WidgetPresentation(
        text: settings.showPercentage == false ? "" : percentage.map { "\($0)%" } ?? "AC power",
        symbol: settings.showSymbol == false ? nil : item.symbol ?? symbol,
        tint: tint,
        accessibilityLabel: label
      )
    case .wifi(let connected):
      guard let settings = item.wifi else {
        return WidgetPresentation(text: text, symbol: item.symbol, accessibilityLabel: text)
      }
      let label =
        connected
        ? settings.connectedLabel ?? "Wi-Fi connected"
        : settings.disconnectedLabel ?? "Wi-Fi disconnected"
      return WidgetPresentation(
        text: settings.showLabel == false ? "" : label,
        symbol: settings.showSymbol == false
          ? nil
          : item.symbol
            ?? (connected
              ? settings.connectedSymbol ?? "wifi" : settings.disconnectedSymbol ?? "wifi.slash"),
        tint: connected ? settings.connectedTint : settings.disconnectedTint,
        hidden: !connected && settings.hideWhenDisconnected == true,
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
  var accessibilityLabel: String
}
