import Foundation
import Testing

@testable import SbarCore

@Suite("Theme")
struct ThemeTests {
  @Test("ItemStyle.resolved: applies item overrides and inherits omitted fields")
  func resolvedAppliesOverridesAndInheritsOmittedFields() {
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
  func resolvedUsesBuiltInDefaultsWithoutStyling() throws {
    let config = try JSONDecoder().decode(
      Configuration.self,
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

  @Test(
    "Configuration.init: preserves partial theme and item styling through round trips"
  )
  func initPreservesPartialStylingThroughRoundTrips() throws {
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
  func validateRejectsMalformedThemeColors(value: String) {
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
  func validateReportsInvalidItemStyleLocation() {
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
  func validateRejectsNonfiniteAndNegativeSpacing(value: Double) {
    var config = Configuration.default
    config.theme = Theme(itemSpacing: value)

    #expect(throws: (any Error).self) { try config.validate() }
  }
}
