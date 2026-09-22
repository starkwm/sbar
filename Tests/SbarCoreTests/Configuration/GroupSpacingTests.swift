import Foundation
import Testing

@testable import SbarCore

@Suite("Item")
struct GroupSpacingTests {
  @Test("init(from:): decodes and round trips independent nested spacing")
  func roundTrip() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        #"{"id":"outer","type":"group","itemSpacing":0,"childStyle":{"horizontalPadding":0},"children":[{"id":"inner","type":"group","itemSpacing":2.5},{"id":"default","type":"group"}]}"#
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(left: [item])).validate()

    #expect(item.itemSpacing == 0)
    #expect(item.childStyle?.horizontalPadding == 0)
    #expect(item.children?[0].itemSpacing == 2.5)
    #expect(item.children?[1].itemSpacing == nil)
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
  }

  @Test(
    "Configuration.validate: validates group spacing bounds",
    arguments: [0.0, 2.5, 96, -1, 97, .infinity, .nan]
  )
  func bounds(spacing: Double) throws {
    let configuration = Configuration(
      bar: .init(),
      items: .init(left: [Item(id: "group", type: .group, itemSpacing: spacing)])
    )

    if (0...96).contains(spacing) {
      try configuration.validate()
    } else {
      #expect(
        throws: ConfigurationError.invalidValue(
          path: "items.left[0].itemSpacing",
          reason: "Must be between 0.0 and 96.0."
        )
      ) { try configuration.validate() }
    }
  }

  @Test("Configuration.validate: validates child styles and rejects them on non-group items")
  func childStyleValidation() throws {
    let group = Item(id: "group", type: .group, childStyle: ItemStyle(horizontalPadding: -1))

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "items.left[0].childStyle.horizontalPadding",
        reason: "Must be between 0.0 and 96.0."
      )
    ) { try Configuration(bar: .init(), items: .init(left: [group])).validate() }

    let text = Item(id: "text", type: .text, childStyle: ItemStyle(horizontalPadding: 0))

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "items.left[0].childStyle",
        reason: "Only group items support childStyle."
      )
    ) { try Configuration(bar: .init(), items: .init(left: [text])).validate() }
  }

  @Test(
    "Configuration.validate: rejects spacing on non-group items",
    arguments: [ItemType.text, .popup]
  )
  func wrongType(type: ItemType) {
    let configuration = Configuration(
      bar: .init(),
      items: .init(left: [Item(id: "item", type: type, itemSpacing: 2)])
    )

    #expect(
      throws: ConfigurationError.invalidValue(
        path: "items.left[0].itemSpacing",
        reason: "Only group items support itemSpacing."
      )
    ) { try configuration.validate() }
  }
}
