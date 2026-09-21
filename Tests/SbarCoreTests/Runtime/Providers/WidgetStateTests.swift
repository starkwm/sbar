import Foundation
import Testing

@testable import SbarCore

@Suite("Widget customization")
struct WidgetStateTests {
  @Test("event refresh captures power changes even when percentage text is unchanged")
  @MainActor
  func powerStateRefresh() throws {
    let runtime = ProviderRuntime()
    let configuration = try JSONDecoder().decode(
      Configuration.self,
      from: Data(
        #"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"battery","type":"battery","battery":{},"refresh":{"mode":"event"}}]}}"#
          .utf8
      )
    )
    runtime.configure(configuration)
    defer { runtime.stop() }
    let item = try #require(configuration.items.active.first)
    runtime.updateWidgetState(
      .battery(percentage: 50, charging: false, pluggedIn: false),
      for: .battery
    )
    #expect(runtime.presentation(for: item)?.symbol == "battery.50percent")
    runtime.updateWidgetState(
      .battery(percentage: 50, charging: false, pluggedIn: true),
      for: .battery
    )
    #expect(runtime.presentation(for: item)?.symbol == "powerplug")
    #expect(runtime.sharedValues[.battery] == "50%")
  }

  @Test("static symbols override automatic state symbols")
  func staticSymbols() {
    let item = Item(id: "battery", type: .battery, symbol: "bolt")
    let state = WidgetState.battery(percentage: 80, charging: false, pluggedIn: true)
    #expect(state.text == "80%")
    #expect(state.presentation(for: item).symbol == "bolt")
    #expect(WidgetState.network(.offline).text == "Offline")
  }

  @Test("omitted widget settings use the same presentation as empty settings")
  func defaultSettings() throws {
    let cases: [(ItemType, WidgetState, ItemSymbol, String)] = [
      (
        .battery, .battery(percentage: 50, charging: false, pluggedIn: false), "battery.50percent",
        "50%"
      ),
      (
        .battery, .battery(percentage: 50, charging: true, pluggedIn: true),
        "battery.100percent.bolt", "50%"
      ),
      (.battery, .battery(percentage: 100, charging: false, pluggedIn: true), "powerplug", "100%"),
      (
        .battery, .battery(percentage: nil, charging: false, pluggedIn: true), "powerplug",
        "AC power"
      ),
      (.network, .network(.wifi), "wifi", "Wi-Fi"),
      (.network, .network(.offline), "network.slash", "Offline"),
    ]
    for (type, state, symbol, text) in cases {
      let omitted = Item(id: "widget", type: type)
      let empty = try JSONDecoder().decode(
        Item.self,
        from: Data("{\"id\":\"widget\",\"type\":\"\(type.rawValue)\",\"\(type.rawValue)\":{}}".utf8)
      )
      let presentation = state.presentation(for: omitted)
      #expect(presentation == state.presentation(for: empty))
      #expect(presentation.symbol == symbol)
      #expect(presentation.text == text)
    }
  }

  @Test("battery distinguishes low, charging, plugged in, and no battery")
  func batteryStates() {
    let item = Item(
      id: "battery",
      type: .battery,
      battery: BatteryConfiguration(
        tints: BatteryTints(low: "#ff0000", charging: "#00ff00", pluggedIn: "#0000ff"),
        lowThreshold: 20
      )
    )
    let low = WidgetState.battery(percentage: 20, charging: false, pluggedIn: false).presentation(
      for: item
    )
    #expect(low.text == "20%")
    #expect(low.symbol == "battery.25percent")
    #expect(low.tint == "#ff0000")
    #expect(!low.accessibilityLabel.isEmpty)
    let charging = WidgetState.battery(percentage: 20, charging: true, pluggedIn: true)
      .presentation(for: item)
    #expect(charging.symbol == "battery.100percent.bolt")
    #expect(charging.tint == "#00ff00")
    let plugged = WidgetState.battery(percentage: 100, charging: false, pluggedIn: true)
      .presentation(for: item)
    #expect(plugged.symbol == "powerplug")
    #expect(plugged.tint == "#0000ff")
    let absent = WidgetState.battery(percentage: nil, charging: false, pluggedIn: true)
      .presentation(for: item)
    #expect(absent.accessibilityLabel == "AC power")
    let normal = WidgetState.battery(percentage: 21, charging: false, pluggedIn: false)
      .presentation(for: item)
    #expect(normal.tint == nil)
  }

  @Test("Wi-Fi labels, symbols, tint, and visibility follow connection state")
  func wifiStates() {
    var item = Item(
      id: "wifi",
      type: .network,
      network: NetworkConfiguration(
        interface: .wifi,
        symbols: NetworkSymbols(wifi: .system("checkmark"), offline: .system("xmark")),
        tints: ["wifi": "#00ff00", "offline": "#ff0000"],
        hideWhenDisconnected: true
      )
    )
    let online = WidgetState.network(.wifi).presentation(for: item)
    #expect(online.text == "Wi-Fi connected")
    #expect(online.symbol == "checkmark")
    #expect(online.tint == "#00ff00")
    #expect(!online.hidden)
    let offline = WidgetState.network(.offline).presentation(for: item)
    #expect(offline.hidden)
    #expect(offline.text == "Wi-Fi disconnected")
    #expect(offline.symbol == "xmark")
    #expect(offline.tint == "#ff0000")

    item.symbol = "star"
    #expect(WidgetState.network(.wifi).presentation(for: item).symbol == "star")
    item.network?.showSymbol = false
    #expect(WidgetState.network(.wifi).presentation(for: item).symbol == nil)
  }

  @Test("settings decode with defaults, round trip, and validate")
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(#"{"id":"battery","type":"battery","battery":{}}"#.utf8)
    )
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    #expect(
      WidgetState.battery(percentage: 50, charging: false, pluggedIn: false).presentation(for: item)
        .symbol == "battery.50percent"
    )
    #expect(throws: ConfigurationError.self) {
      try BatteryConfiguration(lowThreshold: 101).validate(path: "battery")
    }
    #expect(throws: ConfigurationError.self) {
      try NetworkConfiguration(tints: ["wifi": "invalid"]).validate(path: "wifi")
    }
  }

}
