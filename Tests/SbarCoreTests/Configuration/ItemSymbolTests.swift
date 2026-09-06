import Foundation
import Testing

@testable import SbarCore

@Suite("Item symbols")
struct ItemSymbolTests {
  @Test("SF Symbols and font glyphs round trip without changing representation")
  func roundTrip() throws {
    for json in [#""wifi""#, #"{"glyph":"\uf1eb","font":"Symbols Nerd Font Mono","size":16}"#] {
      let symbol = try JSONDecoder().decode(ItemSymbol.self, from: Data(json.utf8))
      let encoded = try JSONEncoder().encode(symbol)
      #expect(try JSONDecoder().decode(ItemSymbol.self, from: encoded) == symbol)
    }
    let legacy = try JSONEncoder().encode(ItemSymbol.system("wifi"))
    #expect(String(decoding: legacy, as: UTF8.self) == #""wifi""#)
  }

  @Test("invalid glyph objects are rejected")
  func invalidGlyphs() {
    for json in [
      #"{"glyph":"x"}"#, #"{"glyph":"","font":"Test"}"#,
      #"{"glyph":"x","font":" "}"#, #"{"glyph":"x","font":"Test","size":0}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(ItemSymbol.self, from: Data(json.utf8))
      }
    }
  }

  @Test("battery levels can mix glyphs and SF Symbols")
  func batteryLevels() throws {
    let glyph = ItemSymbol.glyph("\u{f240}", font: "Symbols Nerd Font Mono")
    let configuredGlyph = BatterySymbol.glyph("\u{f240}", font: "Symbols Nerd Font Mono")
    var item = Item(
      id: "battery",
      type: .battery,
      battery: BatteryConfiguration(
        symbols: BatterySymbols(
          levels: [
            .system("battery.0percent"), configuredGlyph, configuredGlyph, configuredGlyph,
            configuredGlyph,
          ],
          charging: configuredGlyph
        )
      )
    )
    try item.battery?.validate(path: "battery")
    #expect(
      WidgetState.battery(percentage: 0, charging: false, pluggedIn: false).presentation(for: item)
        .symbol == "battery.0percent"
    )
    #expect(
      WidgetState.battery(percentage: 100, charging: false, pluggedIn: false).presentation(
        for: item
      ).symbol == glyph
    )
    #expect(
      WidgetState.battery(percentage: 50, charging: true, pluggedIn: true).presentation(for: item)
        .symbol == glyph
    )
    item.battery?.symbols?.levels = [configuredGlyph]
    #expect(throws: ConfigurationError.self) { try item.battery?.validate(path: "battery") }
  }

  @Test("grouped battery symbols inherit defaults and preserve overrides on round trip")
  func groupedBatterySymbols() throws {
    let json = #"""
      {"id":"battery","type":"battery","battery":{
        "symbols":{"font":"Shared","size":18,
          "levels":["battery.0percent",{"glyph":"a"},{"glyph":"b","font":"Other"},
            {"glyph":"c","size":24},{"glyph":"d","font":"Other","size":20}],
          "charging":{"glyph":"bolt"}},
        "tints":{"low":"#ff0000","charging":"#00ff00","pluggedIn":"#0000ff"}
      }}
      """#
    var item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
    try item.battery?.validate(path: "battery")
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    let expected: [ItemSymbol] = [
      .system("battery.0percent"), .glyph("a", font: "Shared", size: 18),
      .glyph("b", font: "Other", size: 18), .glyph("c", font: "Shared", size: 24),
      .glyph("d", font: "Other", size: 20),
    ]
    for (index, symbol) in expected.enumerated() {
      let result = WidgetState.battery(percentage: index * 25, charging: false, pluggedIn: false)
        .presentation(for: item)
      #expect(result.symbol == symbol)
      #expect(result.tint == (index == 0 ? "#ff0000" : nil))
    }
    let charging = WidgetState.battery(percentage: 20, charging: true, pluggedIn: true)
    #expect(charging.presentation(for: item).symbol == .glyph("bolt", font: "Shared", size: 18))
    #expect(charging.presentation(for: item).tint == "#00ff00")
    let pluggedIn = WidgetState.battery(percentage: nil, charging: false, pluggedIn: true)
    #expect(pluggedIn.presentation(for: item).symbol == "powerplug")
    #expect(pluggedIn.presentation(for: item).tint == "#0000ff")
    item.battery?.symbols?.pluggedIn = .glyph("plug")
    #expect(pluggedIn.presentation(for: item).symbol == .glyph("plug", font: "Shared", size: 18))
    item.symbol = "star"
    #expect(charging.presentation(for: item).symbol == "star")
    item.battery?.showSymbol = false
    #expect(charging.presentation(for: item).symbol == nil)
  }

  @Test("grouped battery configuration validates inherited glyphs and tints")
  func invalidGroupedBatterySettings() throws {
    for json in [
      #"{"symbols":{"charging":{"glyph":"x"}}}"#,
      #"{"symbols":{"font":" "}}"#,
      #"{"symbols":{"size":73}}"#,
      #"{"symbols":{"levels":["battery.0percent"]}}"#,
      #"{"symbols":{"font":"Shared","charging":{"glyph":" "}}}"#,
      #"{"symbols":{"font":"Shared","charging":{"glyph":"x","font":" "}}}"#,
      #"{"symbols":{"font":"Shared","charging":{"glyph":"x","size":7}}}"#,
      #"{"tints":{"low":"red"}}"#,
      #"{"tints":{"charging":"red"}}"#,
      #"{"tints":{"pluggedIn":"red"}}"#,
    ] {
      let settings = try JSONDecoder().decode(BatteryConfiguration.self, from: Data(json.utf8))
      #expect(throws: ConfigurationError.self) { try settings.validate(path: "battery") }
    }
    for json in [
      #"{"symbols":{},"tints":{}}"#,
      #"{"symbols":{"charging":{"glyph":"x","font":"Local"}}}"#,
      #"{"symbols":{"font":"Shared","size":8,"charging":{"glyph":"x","size":72}}}"#,
    ] {
      let settings = try JSONDecoder().decode(BatteryConfiguration.self, from: Data(json.utf8))
      try settings.validate(path: "battery")
    }
    let item = Item(
      id: "battery",
      type: .battery,
      battery: BatteryConfiguration(symbols: BatterySymbols())
    )
    #expect(
      WidgetState.battery(percentage: 50, charging: false, pluggedIn: false)
        .presentation(for: item).symbol == "battery.50percent"
    )
  }

  @Test("glyphs decode in item and Wi-Fi state symbols")
  func wifiGlyphs() throws {
    let json =
      #"{"id":"wifi","type":"wifi","wifi":{"connectedSymbol":{"glyph":"\uf1eb","font":"Symbols Nerd Font Mono"}}}"#
    var item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
    let glyph = ItemSymbol.glyph("\u{f1eb}", font: "Symbols Nerd Font Mono")
    #expect(WidgetState.wifi(connected: true).presentation(for: item).symbol == glyph)
    #expect(WidgetState.wifi(connected: false).presentation(for: item).symbol == "wifi.slash")
    item.symbol = glyph
    #expect(WidgetState.wifi(connected: false).presentation(for: item).symbol == glyph)
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
  }
}
