import Testing

@testable import SbarCore

@Suite("OverflowSelection")
struct OverflowSelectionTests {
  @Test("OverflowSelection.visibleItemIDs: preserves priority under constrained width")
  func visibleItemIDsPreservesPriorityUnderConstrainedWidth() {
    let items: [ItemConfiguration] = [
      .init(id: "a", type: .text), .init(id: "b", type: .text, priority: 10),
      .init(id: "c", type: .text),
    ]

    #expect(
      OverflowSelection.visibleItemIDs(
        items: items,
        widths: ["a": 40, "b": 40, "c": 40],
        available: 80,
        spacing: 5
      ) == ["b"]
    )
  }
}
