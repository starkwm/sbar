import Foundation
import Testing

@testable import sbar

@Suite("Theme resolution and validation")
struct ThemeTests {
  @Test("Item overrides win while omitted fields inherit the theme")
  func inheritance() {
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

  @Test("Empty styling retains built-in defaults")
  func defaults() throws {
    let config = try JSONDecoder().decode(
      BarConfiguration.self,
      from: Data(#"{"schemaVersion":1,"bar":{},"items":{}}"#.utf8)
    )
    #expect(config.theme == nil)
    let style = ItemStyle().resolved(over: config.theme?.itemStyle)
    #expect(style.fontSize == 13)
    #expect(style.fontWeight == .regular)
    #expect(style.tint == nil)
    #expect(style.background == nil)
    #expect(style.horizontalPadding == 0)
  }

  @Test("Partial theme and item styling survive configuration round trips")
  func roundTrip() throws {
    let json =
      ##"{"schemaVersion":1,"bar":{},"theme":{"itemSpacing":5,"itemStyle":{"tint":"#aabbcc","fontWeight":"semibold"}},"items":{"right":[{"id":"clock","type":"clock","style":{"fontSize":16,"background":"#11223380"}}]}}"##
    let config = try JSONDecoder().decode(BarConfiguration.self, from: Data(json.utf8))
    try config.validate()
    #expect(config.theme?.horizontalPadding == nil)
    #expect(config.items.right[0].style?.fontSize == 16)
    #expect(
      try JSONDecoder().decode(BarConfiguration.self, from: JSONEncoder().encode(config)) == config
    )
  }

  @Test("Colors accept RGB and RGBA with an alpha suffix")
  func colors() throws {
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
    "Malformed colors are rejected",
    arguments: ["red", "#fff", "#gg0000", "#1234567", "123456", "#１２３４５６"]
  )
  func invalidColors(value: String) {
    #expect(RGBA(hex: value) == nil)
    var config = BarConfiguration.default
    config.theme = BarTheme(background: value)
    #expect(
      throws: ConfigurationError.invalidStyle(
        path: "theme.background",
        reason: "Use #RRGGBB or #RRGGBBAA."
      )
    ) {
      try config.validate()
    }
  }

  @Test("Invalid item styles report their exact location")
  func invalidItem() {
    var config = BarConfiguration.default
    config.items.right[1].style = ItemStyle(fontSize: 0)
    #expect(
      throws: ConfigurationError.invalidStyle(
        path: "items.right[1].style.fontSize",
        reason: "Must be between 8.0 and 72.0."
      )
    ) {
      try config.validate()
    }
  }

  @Test(
    "Nonfinite and negative spacing is rejected",
    arguments: [-1.0, Double.infinity, Double.nan]
  )
  func invalidSpacing(value: Double) {
    var config = BarConfiguration.default
    config.theme = BarTheme(itemSpacing: value)
    #expect(throws: (any Error).self) { try config.validate() }
  }
}
