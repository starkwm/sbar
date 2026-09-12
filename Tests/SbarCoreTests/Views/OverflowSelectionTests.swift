import Foundation
import Testing

@testable import SbarCore

@Suite("OverflowSelection")
struct OverflowSelectionTests {
  @Test(
    "hidden items consume no overflow space, including stale measured widths",
    arguments: [0, 200]
  )
  @MainActor
  func hiddenItemsDoNotDisplaceVisibleContent(measuredWidth: Int) {
    let runtime = ProviderRuntime()
    let media = Item(
      id: "media",
      type: .media,
      priority: 10,
      media: MediaConfiguration(hideWhenNotPlaying: true)
    )
    let text = Item(id: "text", type: .text, label: "Visible item")
    let disabled = Item(id: "disabled", type: .text, enabled: false, priority: 100)
    let items = [text, media, disabled]
    runtime.updateWidgetState(.media(MediaState()), for: .media)
    let displayed = items.filter { runtime.isVisible($0) }
    #expect(displayed.map(\.id) == [text.id])
    let selected = OverflowSelection.visibleItemIDs(
      items: displayed,
      widths: [text.id: 100, media.id: CGFloat(measuredWidth), disabled.id: 200],
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
        widths: [text.id: 100, media.id: 120],
        available: 160,
        spacing: 10
      ) == [media.id]
    )
  }

  @Test("OverflowSelection.visibleItemIDs: preserves priority under constrained width")
  func visibleItemIDsPreservesPriorityUnderConstrainedWidth() {
    let items: [Item] = [
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
