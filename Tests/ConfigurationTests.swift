import Foundation
import Testing
@testable import StarkBar

@Suite("Bar configuration")
struct ConfigurationTests {
    @Test("Example configuration decodes")
    func exampleConfigurationDecodes() throws {
        let data = Data(#"""
        {"schemaVersion":1,"bar":{"position":"top","height":32,"displays":"all"},"items":{"left":[{"id":"app","type":"frontApplication"}],"center":[],"right":[{"id":"clock","type":"clock","format":"HH:mm"}]}}
        """#.utf8)
        let configuration = try JSONDecoder().decode(BarConfiguration.self, from: data)
        try configuration.validate()
        #expect(configuration.items.left.first?.id == "app")
        #expect(configuration.bar.displays == .all)
    }

    @Test("Duplicate item IDs fail validation")
    func duplicateItemIDsFailValidation() {
        let item = ItemConfiguration(id: "same", type: .text)
        let configuration = BarConfiguration(schemaVersion: 1, bar: .init(), items: .init(left: [item], right: [item]))
        #expect(throws: ConfigurationError.duplicateItemIdentifier) { try configuration.validate() }
    }

    @Test("Unsupported heights fail validation")
    func unsupportedHeightsFailValidation() {
        let configuration = BarConfiguration(schemaVersion: 1, bar: .init(height: 10), items: .init())
        #expect(throws: ConfigurationError.invalidBarHeight(10)) { try configuration.validate() }
    }
}
