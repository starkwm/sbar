import Foundation
import Testing

@testable import SbarCore

@Suite("ItemSymbolPosition")
struct ItemSymbolPositionTests {
  @Test(
    "init(from:): omitted and null positions default to the left",
    arguments: ["", ",\"symbolPosition\":null"]
  )
  func defaults(setting: String) throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data("{\"id\":\"text\",\"type\":\"text\"\(setting)}".utf8)
    )

    #expect(item.symbolPosition == .left)
    #expect(Item(id: "text", type: .text).symbolPosition == .left)

    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any]
    )

    #expect(encoded["symbolPosition"] as? String == "left")
  }

  @Test(
    "init(from:): invalid positions fail at the item setting",
    arguments: ["\"top\"", "\"leading\"", "\"Left\"", "\"\"", "1", "true", "{}", "[]"]
  )
  func invalidValues(value: String) throws {
    let data = Data(
      """
      {"schemaVersion":1,"bar":{},"items":{"left":[
        {"id":"text","type":"text","symbolPosition":\(value)}
      ]}}
      """.utf8
    )

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Configuration.self, from: data)
    }

    do {
      _ = try JSONDecoder().decode(Configuration.self, from: data)
    } catch {
      #expect(ConfigurationStore.describe(error).contains("items.left[0].symbolPosition"))
    }
  }

  @Test("encode(to:): both positions decode and encode", arguments: ItemSymbolPosition.allCases)
  func roundTrip(position: ItemSymbolPosition) throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        "{\"id\":\"text\",\"type\":\"text\",\"symbolPosition\":\"\(position.rawValue)\"}".utf8
      )
    )

    #expect(item == Item(id: "text", type: .text, symbolPosition: position))

    let data = try JSONEncoder().encode(item)
    let encoded = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(encoded["symbolPosition"] as? String == position.rawValue)
    #expect(try JSONDecoder().decode(Item.self, from: data) == item)
  }

  @Test("Item.init(from:): nested items choose their own position")
  func nestedItems() throws {
    let configuration = try JSONDecoder().decode(
      Configuration.self,
      from: Data(
        #"""
        {"schemaVersion":1,"bar":{},"items":{"right":[
          {"id":"popup","type":"popup","symbolPosition":"right","children":[
            {"id":"default","type":"text"},
            {"id":"left","type":"text","symbolPosition":"left"},
            {"id":"right","type":"battery","symbolPosition":"right"}
          ]}
        ]}}
        """#.utf8
      )
    )
    try configuration.validate()

    #expect(configuration.items.all.map(\.symbolPosition) == [.right, .left, .left, .right])
    #expect(
      try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration))
        == configuration
    )
  }
}
