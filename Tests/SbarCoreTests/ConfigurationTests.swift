import Foundation
import Testing

@testable import SbarCore

@Suite("BarConfiguration")
struct ConfigurationTests {
  @Test("init: decodes the example configuration")
  func initDecodesExampleConfiguration() throws {
    let data = Data(
      #"""
      {"schemaVersion":1,"bar":{"position":"top","height":32,"displays":"all"},"items":{"left":[{"id":"app","type":"frontApplication"}],"center":[],"right":[{"id":"clock","type":"clock","format":"HH:mm"}]}}
      """#.utf8
    )

    let configuration = try JSONDecoder().decode(BarConfiguration.self, from: data)
    try configuration.validate()

    #expect(configuration.items.left.first?.id == "app")
    #expect(configuration.bar.displays == .all)
  }

  @Test("init: defaults omitted bar settings and item sections")
  func initDefaultsOmittedSettingsAndSections() throws {
    let configuration = try JSONDecoder().decode(
      BarConfiguration.self,
      from: Data(#"{"schemaVersion":1,"bar":{},"items":{}}"#.utf8)
    )

    #expect(configuration.bar == BarSettings())
    #expect(configuration.items.all.isEmpty)
  }

  @Test("init: migrates version-one commands recursively")
  func initMigratesVersionOneCommandsRecursively() throws {
    let json =
      #"{"schemaVersion":1,"bar":{},"items":{"left":[{"id":"group","type":"group","children":[{"id":"c","type":"command","command":{"script":"date","interval":12,"event":"refresh"}}]}]}}"#

    let configuration = try JSONDecoder().decode(BarConfiguration.self, from: Data(json.utf8))
    try configuration.validate()

    let item = try #require(configuration.items.left.first?.children?.first)

    #expect(configuration.schemaVersion == 2)
    #expect(item.refresh == RefreshPolicy(mode: .interval, seconds: 12, event: "refresh"))
    #expect(item.command?.interval == nil)
    #expect(item.command?.event == nil)
  }

  @Test("validate: rejects duplicate item IDs")
  func validateRejectsDuplicateItemIDs() {
    let item = ItemConfiguration(id: "same", type: .text)
    let configuration = BarConfiguration(
      schemaVersion: BarConfiguration.currentSchemaVersion,
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
  func validateRejectsUnsupportedHeights() {
    let configuration = BarConfiguration(
      schemaVersion: BarConfiguration.currentSchemaVersion,
      bar: .init(height: 10),
      items: .init()
    )

    #expect(throws: ConfigurationError.invalidBarHeight(10)) { try configuration.validate() }
  }

  @Test("validate: reports the location of whitespace-only item IDs")
  func validateReportsWhitespaceOnlyItemIDs() {
    let configuration = BarConfiguration(
      schemaVersion: BarConfiguration.currentSchemaVersion,
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
  func validateRequiresDisplayIDsAndRefreshDurations() {
    var config = BarConfiguration.default
    config.bar.displays = .selected

    #expect(throws: (any Error).self) { try config.validate() }

    config.bar.displayIDs = [1]
    config.items.right[1].refresh = RefreshPolicy(mode: .interval)

    #expect(throws: (any Error).self) { try config.validate() }
  }
}
