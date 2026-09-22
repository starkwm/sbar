import Foundation
import Testing

@testable import SbarCore

@Suite("ConfigurationSchema")
struct ConfigurationSchemaTests {
  @Test("data: hover colour schema and decoding accept the same RGB and RGBA strings")
  func hoverColours() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let style = try #require(definitions["itemStyle"] as? [String: Any])
    let properties = try #require(style["properties"] as? [String: Any])

    for key in ["hoverTint", "hoverBackground"] {
      let field = try #require(properties[key] as? [String: Any])

      #expect(field["type"] as? [String] == ["string", "null"])

      let pattern = try #require(field["pattern"] as? String)

      for value in ["#112233", "#AABBCC80", "#00000000", "red", "#fff", "#gg0000"] {
        let matches = value.range(of: pattern, options: .regularExpression) != nil
        let decoded = try JSONDecoder().decode(
          ItemStyle.self,
          from: JSONSerialization.data(withJSONObject: [key: value])
        )

        #expect(matches == (RGBA(hex: value) != nil))

        if matches {
          try decoded.validate(path: "style")
        } else {
          #expect(throws: (any Error).self) { try decoded.validate(path: "style") }
        }
      }
    }
  }

  @Test("data: item sizing schema matches the accepted width bounds and alignments")
  func itemSizing() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let style = try #require(definitions["itemStyle"] as? [String: Any])
    let properties = try #require(style["properties"] as? [String: Any])

    for key in ["minWidth", "width"] {
      let field = try #require(properties[key] as? [String: Any])

      #expect(field["type"] as? [String] == ["number", "null"])

      let lower = try #require(field["minimum"] as? Double)
      let upper = try #require(field["maximum"] as? Double)

      for value in [lower, upper] {
        let decoded = try JSONDecoder().decode(
          ItemStyle.self,
          from: JSONSerialization.data(withJSONObject: [key: value])
        )
        try decoded.validate(path: "style")
      }
      for value in [lower - 1, upper + 1] {
        let decoded = try JSONDecoder().decode(
          ItemStyle.self,
          from: JSONSerialization.data(withJSONObject: [key: value])
        )

        #expect(throws: (any Error).self) { try decoded.validate(path: "style") }
      }
    }

    let alignment = try #require(properties["alignment"] as? [String: Any])
    let values = try #require(alignment["enum"] as? [Any])

    #expect(Set(values.compactMap { $0 as? String }) == Set(ItemAlignment.allCases.map(\.rawValue)))
    #expect(values.contains { $0 is NSNull })
  }

  @Test("data: matches the supported schema version and item types")
  func schema() throws {
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

  @Test("data: symbol positions match decoding choices and default")
  func symbolPositions() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let item = try #require(definitions["item"] as? [String: Any])
    let properties = try #require(item["properties"] as? [String: Any])
    let position = try #require(properties["symbolPosition"] as? [String: Any])
    let values = try #require(position["enum"] as? [Any])

    #expect(
      Set(values.compactMap { $0 as? String }) == Set(ItemSymbolPosition.allCases.map(\.rawValue))
    )
    #expect(values.contains { $0 is NSNull })
    #expect(position["default"] as? String == Item(id: "text", type: .text).symbolPosition.rawValue)
    #expect((item["required"] as? [String])?.contains("symbolPosition") == false)
  }
}
