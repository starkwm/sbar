import AppKit
import Testing

@testable import SbarCore

@Suite("SpacesProvider")
@MainActor
struct SpacesProviderTests {
  @Test("label: numbers Spaces across displays including fullscreen Spaces")
  func labelNumbersSpacesAcrossDisplays() {
    let displays: [[String: Any]] = [
      ["Spaces": [["ManagedSpaceID": 10, "type": 0], ["ManagedSpaceID": 20, "type": 4]]],
      ["Spaces": [["ManagedSpaceID": 30, "type": 0]]],
    ]

    #expect(SpacesProvider.label(displays: displays, activeSpaceID: 10) == "1")
    #expect(SpacesProvider.label(displays: displays, activeSpaceID: 20) == "2")
    #expect(SpacesProvider.label(displays: displays, activeSpaceID: 30) == "3")
  }

  @Test("label: follows reordered Spaces without treating IDs as indexes")
  func labelFollowsReorderedSpaces() {
    let displays: [[String: Any]] = [
      ["Spaces": [["ManagedSpaceID": 70], ["ManagedSpaceID": 10]]]
    ]

    #expect(SpacesProvider.label(displays: displays, activeSpaceID: 10) == "2")
  }

  @Test("label: ignores duplicate IDs and malformed entries")
  func labelIgnoresDuplicateAndMalformedEntries() {
    let displays: [[String: Any]] = [
      [:],
      ["Spaces": [["ManagedSpaceID": 0], [:], ["ManagedSpaceID": 10]]],
      ["Spaces": [["ManagedSpaceID": 10], ["ManagedSpaceID": 20]]],
    ]

    #expect(SpacesProvider.label(displays: displays, activeSpaceID: 20) == "2")
  }

  @Test("label: reports unavailable for missing active Spaces")
  func labelReportsMissingActiveSpace() {
    #expect(SpacesProvider.label(displays: [], activeSpaceID: 0) == "Spaces unavailable")
    #expect(
      SpacesProvider.label(displays: [["Spaces": [["ManagedSpaceID": 10]]]], activeSpaceID: 20)
        == "Spaces unavailable"
    )
  }

  @Test("start: replaces observers and stops delivering updates after stop")
  func startReplacesObserversAndStopsUpdates() async throws {
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
