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
    var item = Item(
      id: "battery",
      type: .battery,
      battery: BatteryConfiguration(
        levelSymbols: ["battery.0percent", glyph, glyph, glyph, glyph],
        chargingSymbol: glyph
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
    item.battery?.levelSymbols = [glyph]
    #expect(throws: ConfigurationError.self) { try item.battery?.validate(path: "battery") }
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
