import Foundation
import Testing

@testable import SbarCore

struct ConfigurationSchemaTests {
  @Test("Bundled schema matches the supported version and item types")
  func schema() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let properties = try #require(schema["properties"] as? [String: Any])
    let version = try #require(properties["schemaVersion"] as? [String: Any])
    #expect(version["const"] as? Int == BarConfiguration.currentSchemaVersion)
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let item = try #require(definitions["item"] as? [String: Any])
    let itemProperties = try #require(item["properties"] as? [String: Any])
    let type = try #require(itemProperties["type"] as? [String: Any])
    let types = try #require(type["enum"] as? [String])
    #expect(Set(types) == Set(ItemType.allCases.map(\.rawValue)))
  }

}
