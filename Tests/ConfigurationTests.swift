import Foundation
import Testing

@testable import sbar

@Suite("Bar configuration")
struct ConfigurationTests {
  @Test("Example configuration decodes")
  func exampleConfigurationDecodes() throws {
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

  @Test("Duplicate item IDs fail validation")
  func duplicateItemIDsFailValidation() {
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

  @Test("Unsupported heights fail validation")
  func unsupportedHeightsFailValidation() {
    let configuration = BarConfiguration(
      schemaVersion: BarConfiguration.currentSchemaVersion,
      bar: .init(height: 10),
      items: .init()
    )
    #expect(throws: ConfigurationError.invalidBarHeight(10)) { try configuration.validate() }
  }

  @Test("Omitted bar settings and sections use defaults")
  func defaultsDecode() throws {
    let configuration = try JSONDecoder().decode(
      BarConfiguration.self,
      from: Data(#"{"schemaVersion":1,"bar":{},"items":{}}"#.utf8)
    )
    #expect(configuration.bar == BarSettings())
    #expect(configuration.items.all.isEmpty)
  }

  @Test("Whitespace IDs report their location")
  func emptyIdentifier() {
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

}
