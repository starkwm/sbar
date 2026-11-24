import AppKit
import StarkSkyLight
import Testing

@testable import SbarCore

@Suite("SpacesProvider")
@MainActor
struct SpacesProviderTests {
  @Test("currentState: uses each display's current query, then its snapshot, then focus on Main")
  func displaySpaces() {
    let spaces = Query()
    let state = SpacesProvider.currentState(using: spaces)

    #expect(state.complete)
    #expect(state.displays.map(\.identifier) == ["display-a", "display-b", "main"])
    #expect(state.displays.map(\.activeID) == [20, 30, 40])
    #expect(state.isFullscreen(displayUUID: "DISPLAY-A"))
    // Space 70 is shared across displays and counts once in the global index.
    #expect(state.text == "4")
  }

  @Test("currentState: missing focus leaves usable display data and triggers retries")
  func missingFocus() {
    var spaces = Query()
    spaces.focused = nil
    let state = SpacesProvider.currentState(using: spaces)

    #expect(!state.complete)
    #expect(state.text == "Spaces unavailable")
    #expect(state.isFullscreen(displayUUID: "DISPLAY-A"))
    #expect(state.displays.last?.activeID == nil)
  }

  @Test("currentState: a malformed snapshot yields the unavailable state")
  func malformedSnapshot() {
    var spaces = Query()
    spaces.malformed = true
    let state = SpacesProvider.currentState(using: spaces)

    #expect(state.text == "Spaces unavailable")
    #expect(!state.complete)
  }

  @Test("start: replaces observers and stops delivering updates after stop")
  func observers() async throws {
    let workspace = NotificationCenter()
    let application = NotificationCenter()
    let state = SpacesProvider.currentState(using: Query())
    let provider = SpacesProvider(query: { state }, workspace: workspace, application: application)
    defer { provider.stop() }
    var previousUpdates = 0
    var updates = 0

    provider.start { _ in previousUpdates += 1 }
    provider.start { _ in updates += 1 }
    workspace.post(
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil
    )

    try await Task.sleep(for: .milliseconds(150))

    #expect(previousUpdates == 1)
    #expect(updates == 2)

    provider.stop()
    workspace.post(
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil
    )

    try await Task.sleep(for: .milliseconds(150))

    #expect(updates == 2)
  }
}

private struct Query: SpaceQuerying {
  var focused: SpaceID? = SpaceID(rawValue: 40)
  var malformed = false

  func snapshot() throws -> SpaceSnapshot {
    if malformed { throw SkyLightError.malformedResponse("displays") }
    let shared = Space(id: SpaceID(rawValue: 70), type: .desktop)
    let twenty = Space(id: SpaceID(rawValue: 20), type: .fullscreen)
    let thirty = Space(id: SpaceID(rawValue: 30), type: .desktop)
    let forty = Space(id: SpaceID(rawValue: 40), type: .unknown(7))
    return SpaceSnapshot(
      displays: [
        DisplaySpaces(
          id: DisplayID(rawValue: "DISPLAY-A"),
          spaces: [shared, twenty],
          currentSpaceID: shared.id
        ),
        DisplaySpaces(
          id: DisplayID(rawValue: "DISPLAY-B"),
          spaces: [shared, thirty],
          currentSpaceID: thirty.id
        ),
        DisplaySpaces(id: DisplayID(rawValue: "Main"), spaces: [forty], currentSpaceID: nil),
      ],
      activeSpaceID: focused
    )
  }

  func currentSpace(for displayID: DisplayID) throws -> SpaceID? {
    switch displayID.rawValue {
    case "DISPLAY-A": SpaceID(rawValue: 20)
    case "DISPLAY-B": throw SkyLightError.queryFailed("currentSpace")
    default: nil
    }
  }

  func activeSpace() throws -> SpaceID? { focused }
  func spaceType(for spaceID: SpaceID) throws -> SpaceType {
    throw SkyLightError.invalidArgument("spaceID")
  }
  func spaceIDs(containing windowID: CGWindowID) throws -> [SpaceID] { [] }
}
