import Foundation
import Testing

@testable import SbarCore

@Suite("Configuration")
struct ConfigurationTests {
  @Test("init(from:): decodes and round trips localized styles")
  func datetimeStyles() throws {
    let data = Data(#"{"id":"date","type":"datetime","dateStyle":"full","timeStyle":"none"}"#.utf8)
    let item = try JSONDecoder().decode(Item.self, from: data)

    #expect(item.type == .datetime)
    #expect(item.dateStyle == .full)
    #expect(item.timeStyle == DateTimeStyle.none)
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        Item.self,
        from: Data(#"{"id":"date","type":"datetime","dateStyle":"invalid"}"#.utf8)
      )
    }
  }

  @Test("init: decodes the example configuration")
  func initDecodesExampleConfiguration() throws {
    let data = Data(
      #"""
      {"schemaVersion":1,"bar":{"position":"top","height":32,"displays":"all"},"items":{"left":[{"id":"app","type":"frontApplication"}],"center":[],"right":[{"id":"clock","type":"datetime","format":"HH:mm"}]}}
      """#.utf8
    )

    let configuration = try JSONDecoder().decode(Configuration.self, from: data)
    try configuration.validate()

    #expect(configuration.items.left.first?.id == "app")
    #expect(configuration.bar.displays == .all)
  }

  @Test("init: defaults omitted bar settings and item sections")
  func defaults() throws {
    let configuration = try JSONDecoder().decode(
      Configuration.self,
      from: Data(#"{"schemaVersion":1,"bar":{},"items":{}}"#.utf8)
    )

    #expect(configuration.bar == BarSettings())
    #expect(configuration.items.all.isEmpty)
  }

  @Test("init: round trips floating bar settings with omitted margin edges")
  func initRoundTripsFloatingSettings() throws {
    let json =
      #"{"schemaVersion":1,"bar":{"margin":{"top":44,"left":12}},"theme":{"verticalPadding":4,"cornerRadius":12},"items":{}}"#
    let configuration = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    try configuration.validate()

    #expect(configuration.bar.margin == BarMargin(top: 44, left: 12))
    #expect(configuration.theme?.verticalPadding == 4)
    #expect(configuration.theme?.cornerRadius == 12)
    #expect(
      try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration))
        == configuration
    )
  }

  @Test("init: preserves native window shadow settings", arguments: [true, false])
  func initPreservesShadow(enabled: Bool) throws {
    let json = "{\"schemaVersion\":1,\"bar\":{\"shadow\":\(enabled)},\"items\":{}}"
    let configuration = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    try configuration.validate()

    #expect(configuration.bar.shadow == enabled)
    #expect(configuration.bar == BarSettings(shadow: enabled))
    #expect(
      try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration))
        == configuration
    )
  }

  @Test(
    "init: omitted and null shadows preserve the default appearance",
    arguments: ["{}", "{\"shadow\":null}"]
  )
  func initDefaultsShadow(bar: String) throws {
    let json = "{\"schemaVersion\":1,\"bar\":\(bar),\"items\":{}}"
    let configuration = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))

    #expect(configuration.bar.shadow == nil)
  }

  @Test("init: rejects nonboolean shadows", arguments: ["\"true\"", "1", "{}"])
  func initRejectsNonbooleanShadow(value: String) {
    let json = "{\"schemaVersion\":1,\"bar\":{\"shadow\":\(value)},\"items\":{}}"

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    }
  }

  @Test("init: decodes version-one refresh policies in groups")
  func groupRefresh() throws {
    let json =
      #"{"schemaVersion":1,"bar":{},"items":{"left":[{"id":"group","type":"group","children":[{"id":"c","type":"command","command":{"script":"date"},"refresh":{"mode":"interval","seconds":12,"event":"refresh"}}]}]}}"#

    let configuration = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    try configuration.validate()

    let item = try #require(configuration.items.left.first?.children?.first)

    #expect(configuration.schemaVersion == 1)
    #expect(item.refresh == RefreshPolicy(mode: .interval, seconds: 12, event: "refresh"))
    #expect(item.command?.script == "date")
  }

  @Test(
    "validate: rejects invalid floating bar dimensions",
    arguments: [-1.0, 4097.0, Double.infinity, Double.nan]
  )
  func validateRejectsInvalidMargins(value: Double) {
    for margin in [
      BarMargin(top: value), BarMargin(bottom: value), BarMargin(left: value),
      BarMargin(right: value),
    ] {
      let configuration = Configuration(bar: .init(margin: margin), items: .init())

      #expect(throws: (any Error).self) { try configuration.validate() }
    }
  }

  @Test("validate: rejects invalid bar padding and radius", arguments: [-1.0, 49.0])
  func invalidDimensions(value: Double) {
    for theme in [Theme(verticalPadding: value), Theme(cornerRadius: value)] {
      let configuration = Configuration(bar: .init(), items: .init(), theme: theme)

      #expect(throws: (any Error).self) { try configuration.validate() }
    }
  }

  @Test("validate: rejects unsupported schema versions", arguments: [0, 2, 3])
  func schemaVersion(version: Int) throws {
    let json = "{\"schemaVersion\":\(version),\"bar\":{},\"items\":{}}"
    let configuration = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))

    #expect(throws: ConfigurationError.unsupportedSchemaVersion(version)) {
      try configuration.validate()
    }
  }

  @Test("validate: rejects duplicate item IDs")
  func validateRejectsDuplicateItemIDs() {
    let item = Item(id: "same", type: .text)
    let configuration = Configuration(
      schemaVersion: Configuration.currentSchemaVersion,
      bar: .init(),
      items: .init(left: [item], right: [item])
    )

    #expect(
      throws: ConfigurationError.invalidItemIdentifier(
        path: "items.right[0].id",
        reason: "Duplicate ID 'same'."
      )
    ) { try configuration.validate() }
  }

  @Test("validate: rejects unsupported bar heights")
  func invalidHeights() {
    let configuration = Configuration(
      schemaVersion: Configuration.currentSchemaVersion,
      bar: .init(height: 10),
      items: .init()
    )

    #expect(throws: ConfigurationError.invalidBarHeight(10)) { try configuration.validate() }
  }

  @Test("validate: reports the location of whitespace-only item IDs")
  func blankIDs() {
    let configuration = Configuration(
      schemaVersion: Configuration.currentSchemaVersion,
      bar: .init(),
      items: .init(center: [.init(id: " ", type: .text)])
    )

    #expect(
      throws: ConfigurationError.invalidItemIdentifier(
        path: "items.center[0].id",
        reason: "Must not be empty."
      )
    ) {
      try configuration.validate()
    }
  }

  @Test("validate: requires selected display IDs and interval refresh durations")
  func requiredSettings() {
    var config = Configuration.default
    config.bar.displays = .selected

    #expect(throws: (any Error).self) { try config.validate() }

    config.bar.displayIDs = [1]
    config.items.right[1].refresh = RefreshPolicy(mode: .interval)

    #expect(throws: (any Error).self) { try config.validate() }
  }
}
