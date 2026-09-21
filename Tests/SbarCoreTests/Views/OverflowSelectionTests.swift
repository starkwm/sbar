import Foundation
import Testing

@testable import SbarCore

@Suite("OverflowSelection")
struct OverflowSelectionTests {
  @Test("vertical overflow uses unscaled heights, preserves priority and reserves its button")
  func verticalOverflow() {
    let items = [
      Item(id: "a", type: .text, priority: 10, style: ItemStyle(width: 400)),
      Item(id: "b", type: .text, style: ItemStyle(minWidth: 200)),
      Item(id: "c", type: .text),
    ]
    #expect(
      OverflowSelection.visibleItemIDs(
        items: items,
        lengths: ["a": 30, "b": 30, "c": 30],
        available: 110,
        spacing: 10,
        isVertical: true
      ) == ["a", "b", "c"]
    )
    #expect(
      OverflowSelection.visibleItemIDs(
        items: items,
        lengths: ["a": 30, "b": 30, "c": 30],
        available: 100,
        spacing: 10,
        isVertical: true
      ) == ["a"]
    )
    #expect(
      OverflowSelection.visibleItemIDs(
        items: [items[0]],
        lengths: ["a": 30],
        available: 29,
        spacing: 0,
        isVertical: true
      ).isEmpty
    )
  }

  @Test(
    "reserved widths are respected before and after measurement, including theme defaults",
    arguments: [ItemStyle(minWidth: 100), ItemStyle(width: 100)],
    [nil, 100] as [CGFloat?]
  )
  func reservedWidths(style: ItemStyle, measuredWidth: CGFloat?) {
    var item = Item(id: "item", type: .text, style: style)
    let widths = measuredWidth.map { [item.id: $0] } ?? [:]
    #expect(
      OverflowSelection.visibleItemIDs(
        items: [item],
        lengths: widths,
        available: 90,
        spacing: 0
      ).isEmpty
    )
    #expect(
      OverflowSelection.visibleItemIDs(
        items: [item],
        lengths: widths,
        available: 100,
        spacing: 0
      ) == [item.id]
    )
    item.style = nil
    #expect(
      OverflowSelection.visibleItemIDs(
        items: [item],
        lengths: widths,
        available: 90,
        spacing: 0,
        defaultStyle: style
      ).isEmpty
    )
  }

  @Test("fixed widths override inherited minimums and stale measurements")
  func fixedWidthOverrides() {
    let item = Item(id: "item", type: .text, style: ItemStyle(width: 60))
    #expect(
      OverflowSelection.visibleItemIDs(
        items: [item],
        lengths: [item.id: 300],
        available: 60,
        spacing: 0,
        defaultStyle: ItemStyle(minWidth: 100, width: 120)
      ) == [item.id]
    )
  }

  @Test("minimum widths allow larger labels and preserve overflow priorities")
  func minimumWidthGrowth() {
    let item = Item(id: "item", type: .text, style: ItemStyle(minWidth: 100))
    #expect(
      OverflowSelection.visibleItemIDs(
        items: [item],
        lengths: [item.id: 200],
        available: 120,
        spacing: 0
      ).isEmpty
    )
    let other = Item(id: "other", type: .text, priority: 10, style: ItemStyle(width: 60))
    #expect(
      OverflowSelection.visibleItemIDs(
        items: [item, other],
        lengths: [item.id: 100, other.id: 60],
        available: 150,
        spacing: 10
      ) == [other.id]
    )
  }

  @Test(
    "hidden items consume no overflow space, including stale measured widths",
    arguments: [0, 200]
  )
  @MainActor
  func hiddenItems(measuredWidth: Int) {
    let runtime = ProviderRuntime()
    let media = Item(
      id: "media",
      type: .media,
      priority: 10,
      media: MediaConfiguration(hideWhenNotPlaying: true)
    )
    let text = Item(id: "text", type: .text, text: "Visible item")
    let disabled = Item(id: "disabled", type: .text, enabled: false, priority: 100)
    let items = [text, media, disabled]
    runtime.updateWidgetState(.media(MediaState()), for: .media)
    let displayed = items.filter { runtime.isVisible($0) }
    #expect(displayed.map(\.id) == [text.id])
    let selected = OverflowSelection.visibleItemIDs(
      items: displayed,
      lengths: [text.id: 100, media.id: CGFloat(measuredWidth), disabled.id: 200],
      available: 80,
      spacing: 10
    )
    #expect(selected == [text.id])
    #expect(selected.count == displayed.count)

    runtime.updateWidgetState(
      .media(
        MediaState(players: [
          .music: MediaPlayerState(source: .music, status: .playing, title: "Playing track")
        ])
      ),
      for: .media
    )
    let playing = items.filter { runtime.isVisible($0) }
    #expect(playing.map(\.id) == [text.id, media.id])
    #expect(
      OverflowSelection.visibleItemIDs(
        items: playing,
        lengths: [text.id: 100, media.id: 120],
        available: 160,
        spacing: 10
      ) == [media.id]
    )
  }

  @Test("OverflowSelection.visibleItemIDs: preserves priority under constrained width")
  func priority() {
    let items: [Item] = [
      .init(id: "a", type: .text), .init(id: "b", type: .text, priority: 10),
      .init(id: "c", type: .text),
    ]

    #expect(
      OverflowSelection.visibleItemIDs(
        items: items,
        lengths: ["a": 40, "b": 40, "c": 40],
        available: 80,
        spacing: 5
      ) == ["b"]
    )
  }
}
