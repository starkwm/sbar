import AppKit
import Testing

@testable import SbarCore

@Suite("Fullscreen bars")
struct FullscreenBarTests {
  @Test("fullscreen follows each display's active Space, independently of focus")
  func perDisplay() {
    var state = SpacesState(
      displays: [
        SpaceDisplay(
          identifier: "display-a",
          spaces: [SpaceEntry(id: 1), SpaceEntry(id: 2, fullscreen: true)],
          activeID: 2
        ),
        SpaceDisplay(
          identifier: "display-b",
          spaces: [SpaceEntry(id: 3), SpaceEntry(id: 4, fullscreen: true)],
          activeID: 3
        ),
      ],
      focusedID: 3
    )
    #expect(state.isFullscreen(displayUUID: "DISPLAY-A"))
    #expect(!state.isFullscreen(displayUUID: "display-b"))
    state.displays[0].activeID = 1
    state.displays[1].activeID = 4
    #expect(!state.isFullscreen(displayUUID: "display-a"))
    #expect(state.isFullscreen(displayUUID: "display-b"))
  }

  @Test("shared Spaces use the main display entry and unknown state keeps bars available")
  func sharedAndUnknownSpaces() {
    let state = SpacesState(displays: [
      SpaceDisplay(identifier: "main", spaces: [SpaceEntry(id: 10, fullscreen: true)], activeID: 10)
    ])
    #expect(state.isFullscreen(displayUUID: "display-a"))
    #expect(state.isFullscreen(displayUUID: "display-b"))
    #expect(!SpacesState().isFullscreen(displayUUID: "display-a"))
    let unknown = SpacesState(displays: [
      SpaceDisplay(
        identifier: "display-a",
        spaces: [SpaceEntry(id: 10, fullscreen: true)],
        activeID: nil
      )
    ])
    #expect(!unknown.isFullscreen(displayUUID: "display-a"))
    #expect(!unknown.isFullscreen(displayUUID: "unmatched"))
  }

  @Test("panels never opt into fullscreen auxiliary windows")
  @MainActor
  func panelBehavior() {
    let panel = BarPanel(contentRect: CGRect(x: 0, y: 0, width: 32, height: 100))
    defer { panel.close() }
    #expect(panel.collectionBehavior.contains(.fullScreenNone))
    #expect(!panel.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
  }
}
