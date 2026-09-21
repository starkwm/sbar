import Foundation
import Testing

@testable import SbarCore

@Suite("Theme")
struct ThemeTests {
  @Test("ItemStyle.resolved: applies item overrides and inherits omitted fields")
  func overrides() {
    let theme = ItemStyle(
      tint: "#112233",
      background: "#223344",
      fontSize: 18,
      fontWeight: .bold,
      horizontalPadding: 8,
      verticalPadding: 4,
      cornerRadius: 6
    )
    let item = ItemStyle(background: "#00000000", fontSize: 14, horizontalPadding: 0)

    let result = item.resolved(over: theme)

    #expect(result.tint == "#112233")
    #expect(result.background == "#00000000")
    #expect(result.fontSize == 14)
    #expect(result.fontWeight == .bold)
    #expect(result.horizontalPadding == 0)
    #expect(result.verticalPadding == 4)
    #expect(result.cornerRadius == 6)
  }

  @Test("ItemStyle.resolved: uses built-in defaults without styling")
  func defaults() throws {
    let config = try JSONDecoder().decode(
      Configuration.self,
      from: Data(#"{"schemaVersion":1,"bar":{},"items":{}}"#.utf8)
    )

    #expect(config.theme == nil)

    let style = ItemStyle().resolved(over: config.theme?.itemStyle)

    #expect(style.fontFamily == nil)
    #expect(style.fontSize == 13)
    #expect(style.fontWeight == .regular)
    #expect(style.tint == nil)
    #expect(style.background == nil)
    #expect(style.horizontalPadding == 0)
    #expect(style.minWidth == nil)
    #expect(style.width == nil)
    #expect(style.alignment == .center)
  }

  @Test("Font families inherit, override and round trip")
  func fontFamilies() throws {
    let json = """
      {"schemaVersion":1,"bar":{},
       "theme":{"itemStyle":{"fontFamily":"Menlo","fontSize":18,"fontWeight":"bold"}},
       "items":{"right":[{"id":"clock","type":"datetime",
         "style":{"fontFamily":"Helvetica Neue"}}]}}
      """
    let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    try config.validate()
    let theme = try #require(config.theme?.itemStyle)

    #expect(ItemStyle().resolved(over: theme).fontFamily == "Menlo")

    let style = try #require(config.items.right[0].style).resolved(over: theme)

    #expect(style.fontFamily == "Helvetica Neue")
    #expect(style.fontSize == 18)
    #expect(style.fontWeight == .bold)

    let inherited = try JSONDecoder().decode(
      ItemStyle.self,
      from: Data(#"{"fontFamily":null}"#.utf8)
    )

    #expect(inherited.resolved(over: theme).fontFamily == "Menlo")
    #expect(
      try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config)) == config
    )
  }

  @Test("Item widths and alignment inherit independently and round trip")
  func itemSizing() throws {
    let json = """
      {"schemaVersion":1,"bar":{},
       "theme":{"itemStyle":{"minWidth":80,"width":120,"alignment":"trailing"}},
       "items":{"right":[{"id":"clock","type":"datetime",
         "style":{"minWidth":0,"width":null,"alignment":"leading"}}]}}
      """
    let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    try config.validate()
    let theme = try #require(config.theme?.itemStyle)
    let inherited = ItemStyle().resolved(over: theme)

    #expect(inherited.minWidth == 80)
    #expect(inherited.width == 120)
    #expect(inherited.alignment == .trailing)

    let style = try #require(config.items.right[0].style).resolved(over: theme)

    #expect(style.minWidth == 0)
    #expect(style.width == 120)
    #expect(style.alignment == .leading)
    #expect(ItemStyle(width: 0).resolved(over: theme).width == 0)
    #expect(
      try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config)) == config
    )
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(ItemStyle.self, from: Data(#"{"alignment":"left"}"#.utf8))
    }
  }

  @Test(
    "Configuration.validate: rejects invalid item widths at their exact locations",
    arguments: [-1.0, 4097, Double.infinity, -Double.infinity, Double.nan],
    ["minWidth", "width"]
  )
  func invalidItemWidths(value: Double, field: String) {
    let style = field == "minWidth" ? ItemStyle(minWidth: value) : ItemStyle(width: value)
    var config = Configuration.default
    config.items.right[1].style = style

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "items.right[1].style.\(field)",
        reason: "Must be between 0.0 and 4096.0."
      )
    ) { try config.validate() }

    config.items.right[1].style = nil
    config.theme = Theme(itemStyle: style)

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "theme.itemStyle.\(field)",
        reason: "Must be between 0.0 and 4096.0."
      )
    ) { try config.validate() }
  }

  @Test(
    "Configuration.init: preserves partial theme and item styling through round trips"
  )
  func roundTrip() throws {
    let json =
      ##"{"schemaVersion":1,"bar":{},"theme":{"itemSpacing":5,"itemStyle":{"tint":"#aabbcc","fontWeight":"semibold"}},"items":{"right":[{"id":"clock","type":"datetime","style":{"fontSize":16,"background":"#11223380"}}]}}"##

    let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    try config.validate()

    #expect(config.theme?.horizontalPadding == nil)
    #expect(config.items.right[0].style?.fontSize == 16)

    #expect(
      try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config)) == config
    )
  }

  @Test("Symbol weight inherits independently and round trips")
  func symbolWeight() throws {
    let theme = ItemStyle(fontWeight: .bold, symbolFontWeight: .medium)
    let inherited = ItemStyle(fontWeight: .regular).resolved(over: theme)

    #expect(inherited.fontWeight == .regular)
    #expect(inherited.symbolFontWeight == .medium)
    #expect(
      ItemStyle(symbolFontWeight: .semibold).resolved(over: theme).symbolFontWeight == .semibold
    )
    #expect(ItemStyle().resolved(over: ItemStyle(fontWeight: .bold)).symbolFontWeight == nil)

    let decoded = try JSONDecoder().decode(
      ItemStyle.self,
      from: Data(#"{"symbolFontWeight":"bold"}"#.utf8)
    )

    #expect(decoded.symbolFontWeight == .bold)
    #expect(
      try JSONDecoder().decode(ItemStyle.self, from: JSONEncoder().encode(decoded)) == decoded
    )
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(ItemStyle.self, from: Data(#"{"symbolFontWeight":"invalid"}"#.utf8))
    }
  }

  @Test("hover colours inherit independently and preserve transparent overrides")
  func hoverColours() throws {
    let json = ##"{"hoverTint":null,"hoverBackground":"#00000000"}"##
    let item = try JSONDecoder().decode(ItemStyle.self, from: Data(json.utf8))
    let theme = ItemStyle(hoverTint: "#FFFFFF", hoverBackground: "#33445580")
    let resolved = item.resolved(over: theme)

    #expect(resolved.hoverTint == "#FFFFFF")
    #expect(resolved.hoverBackground == "#00000000")
    #expect(ItemStyle(hoverTint: "#112233").resolved(over: theme).hoverTint == "#112233")
    #expect(ItemStyle().resolved(over: theme).hoverBackground == "#33445580")
    #expect(ItemStyle().resolved(over: nil).hoverTint == nil)
    #expect(ItemStyle().resolved(over: nil).hoverBackground == nil)

    try resolved.validate(path: "style")

    #expect(
      try JSONDecoder().decode(ItemStyle.self, from: JSONEncoder().encode(resolved)) == resolved
    )
  }

  @Test(
    "hover colour validation reports the exact item or theme field",
    arguments: ["hoverTint", "hoverBackground"],
    ["red", "#fff", "#gg0000", "#1234567"]
  )
  func invalidHoverColours(field: String, value: String) throws {
    let style = try JSONDecoder().decode(
      ItemStyle.self,
      from: JSONSerialization.data(withJSONObject: [field: value])
    )
    var config = Configuration.default
    config.items.right[1].style = style

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "items.right[1].style.\(field)",
        reason: "Use #RRGGBB or #RRGGBBAA."
      )
    ) { try config.validate() }

    config.items.right[1].style = nil
    config.theme = Theme(itemStyle: style)

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "theme.itemStyle.\(field)",
        reason: "Use #RRGGBB or #RRGGBBAA."
      )
    ) { try config.validate() }
  }

  @Test("RGBA.init: accepts RGB and RGBA with an alpha suffix")
  func initAcceptsRGBAndRGBA() throws {
    let rgb = try #require(RGBA(hex: "#FF0080"))

    #expect(rgb.red == 1)
    #expect(rgb.green == 0)
    #expect(rgb.blue == Double(128) / 255)
    #expect(rgb.alpha == 1)

    let rgba = try #require(RGBA(hex: "#ff008000"))

    #expect(rgba.alpha == 0)
    #expect(rgba.red == rgb.red)
  }

  @Test(
    "Configuration.validate: rejects malformed theme colors",
    arguments: ["red", "#fff", "#gg0000", "#1234567", "123456", "#１２３４５６"]
  )
  func invalidColors(value: String) {
    #expect(RGBA(hex: value) == nil)

    var config = Configuration.default
    config.theme = Theme(background: value)

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "theme.background",
        reason: "Use #RRGGBB or #RRGGBBAA."
      )
    ) {
      try config.validate()
    }
  }

  @Test("Configuration.validate: reports the exact location of invalid item styles")
  func errorPath() {
    var config = Configuration.default
    config.items.right[1].style = ItemStyle(fontSize: 0)

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "items.right[1].style.fontSize",
        reason: "Must be between 8.0 and 72.0."
      )
    ) {
      try config.validate()
    }
  }

  @Test(
    "Configuration.validate: rejects nonfinite and negative theme spacing",
    arguments: [-1.0, Double.infinity, Double.nan]
  )
  func invalidSpacing(value: Double) {
    var config = Configuration.default
    config.theme = Theme(itemSpacing: value)

    #expect(throws: (any Error).self) { try config.validate() }
  }
}
