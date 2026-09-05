import Foundation
import Testing

@testable import SbarCore

@Suite("ConfigurationSchema")
struct ConfigurationSchemaTests {
  @Test("data: matches the supported schema version and item types")
  func dataMatchesSupportedVersionAndItemTypes() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let properties = try #require(schema["properties"] as? [String: Any])
    let version = try #require(properties["schemaVersion"] as? [String: Any])

    #expect(version["const"] as? Int == Configuration.currentSchemaVersion)

    let definitions = try #require(schema["$defs"] as? [String: Any])
    let item = try #require(definitions["item"] as? [String: Any])
    let itemProperties = try #require(item["properties"] as? [String: Any])
    let type = try #require(itemProperties["type"] as? [String: Any])
    let types = try #require(type["enum"] as? [String])

    #expect(Set(types) == Set(ItemType.allCases.map(\.rawValue)))
  }
}
