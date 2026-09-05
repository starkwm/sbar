import Testing

@testable import SbarCore

@Suite("ItemSections")
struct ItemSectionsTests {
  @Test("ItemSections.active: excludes children of disabled groups")
  func activeExcludesChildrenOfDisabledGroups() {
    let group = Item(
      id: "g",
      type: .group,
      enabled: false,
      children: [.init(id: "app", type: .frontApplication)]
    )

    #expect(ItemSections(left: [group]).active.isEmpty)
  }
}
