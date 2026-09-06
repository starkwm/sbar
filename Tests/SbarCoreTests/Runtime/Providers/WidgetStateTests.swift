import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("Widget customization")
struct WidgetStateTests {
  @Test("default symbols exist on macOS")
  func symbols() {
    for symbol in [
      "battery.0percent", "battery.25percent", "battery.50percent",
      "battery.75percent", "battery.100percent", "battery.100percent.bolt",
      "powerplug", "wifi", "wifi.slash",
    ] {
      #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil)
    }
  }

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

  @Test("legacy text and static symbols are preserved")
  func legacy() {
    let item = Item(id: "battery", type: .battery, symbol: "bolt")
    let state = WidgetState.battery(percentage: 80, charging: false, pluggedIn: true)
    #expect(state.text == "80%")
    #expect(state.presentation(for: item).symbol == "bolt")
    #expect(WidgetState.wifi(connected: false).text == "Wi-Fi disconnected")
  }

  @Test("battery distinguishes low, charging, plugged in, and no battery")
  func batteryStates() {
    let item = Item(
      id: "battery",
      type: .battery,
      battery: BatteryConfiguration(
        tints: BatteryTints(low: "#ff0000", charging: "#00ff00", pluggedIn: "#0000ff"),
        showPercentage: false,
        lowThreshold: 20
      )
    )
    let low = WidgetState.battery(percentage: 20, charging: false, pluggedIn: false).presentation(
      for: item
    )
    #expect(low.text.isEmpty)
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
      type: .wifi,
      wifi: WifiConfiguration(
        symbols: WifiSymbols(connected: .system("checkmark"), disconnected: .system("xmark")),
        tints: WifiTints(connected: "#00ff00", disconnected: "#ff0000"),
        connectedLabel: "Online",
        disconnectedLabel: "Offline",
        hideWhenDisconnected: true
      )
    )
    let online = WidgetState.wifi(connected: true).presentation(for: item)
    #expect(online.text == "Online")
    #expect(online.symbol == "checkmark")
    #expect(online.tint == "#00ff00")
    #expect(!online.hidden)
    let offline = WidgetState.wifi(connected: false).presentation(for: item)
    #expect(offline.hidden)
    #expect(offline.text == "Offline")
    #expect(offline.symbol == "xmark")
    #expect(offline.tint == "#ff0000")
    item.wifi?.showLabel = false
    #expect(WidgetState.wifi(connected: true).presentation(for: item).text.isEmpty)
    item.symbol = "star"
    #expect(WidgetState.wifi(connected: true).presentation(for: item).symbol == "star")
    item.wifi?.showSymbol = false
    #expect(WidgetState.wifi(connected: true).presentation(for: item).symbol == nil)
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
      try WifiConfiguration(tints: WifiTints(connected: "invalid")).validate(path: "wifi")
    }
  }

  @Test("manual refresh holds the complete state until triggered")
  @MainActor
  func refresh() throws {
    let runtime = ProviderRuntime()
    let configuration = try JSONDecoder().decode(
      Configuration.self,
      from: Data(
        #"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"wifi","type":"wifi","wifi":{},"refresh":{"mode":"manual"}}]}}"#
          .utf8
      )
    )
    runtime.configure(configuration)
    defer { runtime.stop() }
    let item = try #require(configuration.items.active.first)
    runtime.updateWidgetState(.wifi(connected: true), for: .wifi)
    runtime.updateWidgetState(.wifi(connected: false), for: .wifi)
    #expect(runtime.presentation(for: item)?.symbol == "wifi")
    runtime.trigger("wifi")
    #expect(runtime.presentation(for: item)?.symbol == "wifi.slash")
  }
}
