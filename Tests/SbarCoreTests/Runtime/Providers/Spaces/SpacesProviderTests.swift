import AppKit
import Testing

@testable import SbarCore

@Suite("SpacesProvider")
@MainActor
struct SpacesProviderTests {
  @Test("SpacesState.parse: numbers Spaces across displays including fullscreen Spaces")
  func spaceNumbers() {
    let displays: [[String: Any]] = [
      ["Spaces": [["ManagedSpaceID": 10, "type": 0], ["ManagedSpaceID": 20, "type": 4]]],
      ["Spaces": [["ManagedSpaceID": 30, "type": 0]]],
    ]

    #expect(SpacesState.parse(displays: displays, activeSpaceID: 10).text == "1")
    #expect(SpacesState.parse(displays: displays, activeSpaceID: 20).text == "2")
    #expect(SpacesState.parse(displays: displays, activeSpaceID: 30).text == "3")
  }

  @Test("SpacesState.parse: follows reordered Spaces without treating IDs as indexes")
  func reorderedSpaces() {
    let displays: [[String: Any]] = [
      ["Spaces": [["ManagedSpaceID": 70], ["ManagedSpaceID": 10]]]
    ]

    #expect(SpacesState.parse(displays: displays, activeSpaceID: 10).text == "2")
  }

  @Test("SpacesState.parse: ignores duplicate IDs and malformed entries")
  func invalidEntries() {
    let displays: [[String: Any]] = [
      [:],
      ["Spaces": [["ManagedSpaceID": 0], [:], ["ManagedSpaceID": 10]]],
      ["Spaces": [["ManagedSpaceID": 10], ["ManagedSpaceID": 20]]],
    ]

    #expect(SpacesState.parse(displays: displays, activeSpaceID: 20).text == "2")
  }

  @Test("SpacesState.parse: reports unavailable for missing active Spaces")
  func missingSpace() {
    #expect(SpacesState.parse(displays: [], activeSpaceID: 0).text == "Spaces unavailable")
    #expect(
      SpacesState.parse(displays: [["Spaces": [["ManagedSpaceID": 10]]]], activeSpaceID: 20).text
        == "Spaces unavailable"
    )
  }

  @Test("start: replaces observers and stops delivering updates after stop")
  func observers() async throws {
    let workspace = NotificationCenter()
    let application = NotificationCenter()
    let state = SpacesState.parse(
      displays: [["Display Identifier": "Main", "Spaces": [["ManagedSpaceID": 10]]]],
      activeSpaceID: 10
    )
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
