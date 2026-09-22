import Foundation
import Testing

@testable import SbarCore

@Suite("ItemSymbol")
struct ItemSymbolTests {
  @Test("init(from:): SF Symbols and font glyphs round trip without changing representation")
  func roundTrip() throws {
    for json in [#""wifi""#, #"{"glyph":"\uf1eb","font":"Symbols Nerd Font Mono","size":16}"#] {
      let symbol = try JSONDecoder().decode(ItemSymbol.self, from: Data(json.utf8))
      let encoded = try JSONEncoder().encode(symbol)

      #expect(try JSONDecoder().decode(ItemSymbol.self, from: encoded) == symbol)
    }

    let encodedSystem = try JSONEncoder().encode(ItemSymbol.system("wifi"))

    #expect(String(decoding: encodedSystem, as: UTF8.self) == #""wifi""#)
  }

  @Test("init(from:): invalid glyph objects are rejected")
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

  @Test("WidgetState.presentation(for:): battery levels can mix glyphs and SF Symbols")
  func batteryLevels() throws {
    let glyph = ItemSymbol.glyph("\u{f240}", font: "Symbols Nerd Font Mono")
    let configuredGlyph = WidgetSymbol.glyph("\u{f240}", font: "Symbols Nerd Font Mono")
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

  @Test(
    "WidgetState.presentation(for:): charging levels select the nearest level and inherit glyph defaults"
  )
  func chargingLevels() throws {
    let json = #"""
      {"symbols":{"font":"Shared","size":18,
        "chargingLevels":["zero",{"glyph":"one"},"two","three","four"],
        "charging":"bolt"}}
      """#
    let settings = try JSONDecoder().decode(BatteryConfiguration.self, from: Data(json.utf8))
    try settings.validate(path: "battery")

    #expect(
      try JSONDecoder().decode(BatteryConfiguration.self, from: JSONEncoder().encode(settings))
        == settings
    )

    var item = Item(id: "battery", type: .battery, battery: settings)

    for (percentage, expected) in [
      (0, ItemSymbol.system("zero")), (12, .system("zero")),
      (13, .glyph("one", font: "Shared", size: 18)),
      (37, .glyph("one", font: "Shared", size: 18)), (38, .system("two")),
      (62, .system("two")), (63, .system("three")), (87, .system("three")),
      (88, .system("four")), (100, .system("four")),
    ] {
      #expect(
        WidgetState.battery(percentage: percentage, charging: true, pluggedIn: true)
          .presentation(for: item).symbol == expected
      )
    }

    #expect(
      WidgetState.battery(percentage: 50, charging: false, pluggedIn: false)
        .presentation(for: item).symbol == "battery.50percent"
    )

    item.battery?.symbols?.chargingLevels = nil

    #expect(
      WidgetState.battery(percentage: 50, charging: true, pluggedIn: true)
        .presentation(for: item).symbol == "bolt"
    )

    for levels: [WidgetSymbol] in [
      [], [.system("one")], Array(repeating: .glyph(" ", font: "Shared"), count: 5),
    ] {
      item.battery?.symbols?.chargingLevels = levels

      #expect(throws: ConfigurationError.self) { try item.battery?.validate(path: "battery") }
    }
  }

  @Test(
    "WidgetState.presentation(for:): grouped battery symbols inherit defaults and preserve overrides on round trip"
  )
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

  @Test(
    "BatteryConfiguration.validate: grouped battery configuration validates inherited glyphs and tints"
  )
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

  @Test(
    "WidgetState.presentation(for:): Wi-Fi glyphs inherit shared defaults and allow local overrides"
  )
  func wifiSymbolDefaults() throws {
    let json = #"""
      {"id":"wifi","type":"network","network":{"interface":"wifi",
        "symbols":{"font":"Shared","size":18,
          "wifi":{"glyph":"a"},
          "offline":{"glyph":"b","font":"Other","size":24}},
        "tints":{"wifi":"#00ff00","offline":"#ff0000"}
      }}
      """#
    let item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
    try item.network?.validate(path: "wifi")

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    #expect(
      WidgetState.network(.wifi).presentation(for: item).symbol
        == .glyph("a", font: "Shared", size: 18)
    )
    #expect(
      WidgetState.network(.offline).presentation(for: item).symbol
        == .glyph("b", font: "Other", size: 24)
    )

    for json in [
      #"{"symbols":{"wifi":{"glyph":"x"}}}"#,
      #"{"symbols":{"font":" "}}"#,
      #"{"symbols":{"size":73}}"#,
      #"{"symbols":{"font":"Shared","wifi":{"glyph":" "}}}"#,
      #"{"symbols":{"font":"Shared","offline":{"glyph":"x","font":" "}}}"#,
      #"{"symbols":{"font":"Shared","offline":{"glyph":"x","size":7}}}"#,
      #"{"tints":{"wifi":"red"}}"#,
      #"{"tints":{"offline":"red"}}"#,
    ] {
      let settings = try JSONDecoder().decode(NetworkConfiguration.self, from: Data(json.utf8))

      #expect(throws: ConfigurationError.self) { try settings.validate(path: "wifi") }
    }
  }

  @Test("Item.init(from:): glyphs decode in item and Wi-Fi state symbols")
  func wifiGlyphs() throws {
    let json =
      #"{"id":"wifi","type":"network","network":{"interface":"wifi","symbols":{"font":"Symbols Nerd Font Mono","wifi":{"glyph":"\uf1eb"}}}}"#
    var item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))
    try item.network?.validate(path: "wifi")
    let glyph = ItemSymbol.glyph("\u{f1eb}", font: "Symbols Nerd Font Mono")

    #expect(WidgetState.network(.wifi).presentation(for: item).symbol == glyph)
    #expect(WidgetState.network(.offline).presentation(for: item).symbol == "wifi.slash")

    item.symbol = glyph

    #expect(WidgetState.network(.offline).presentation(for: item).symbol == glyph)
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
  }
}
