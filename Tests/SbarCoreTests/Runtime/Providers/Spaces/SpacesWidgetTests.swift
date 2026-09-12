import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("Spaces widget")
@MainActor
struct SpacesWidgetTests {
  private var snapshot: SpacesState {
    SpacesState.parse(
      displays: [
        [
          "Display Identifier": "DISPLAY-A", "Current Space": ["ManagedSpaceID": 20],
          "Spaces": [["ManagedSpaceID": 10, "type": 0], ["ManagedSpaceID": 20, "type": 4]],
        ],
        [
          "Display Identifier": "DISPLAY-B", "Current Space": ["ManagedSpaceID": 40],
          "Spaces": [["ManagedSpaceID": 30, "type": 0], ["ManagedSpaceID": 40, "type": 0]],
        ],
      ],
      activeSpaceID: 20
    )
  }

  @Test("scope preserves global order and each display's current Space")
  func scopes() {
    let focused = Item(
      id: "spaces",
      type: .spaces,
      text:
        "{{#available}}{{index}} / {{total}}{{/available}}{{^available}}{{value}}{{/available}}",
      spaces: SpacesConfiguration()
    )
    #expect(snapshot.complete)
    #expect(snapshot.presentation(for: focused).text == "2 / 4")
    var local = focused
    local.spaces?.scope = .display
    #expect(snapshot.presentation(for: local, displayUUID: "display-a").text == "2 / 2")
    #expect(snapshot.presentation(for: local, displayUUID: "DISPLAY-B").text == "2 / 2")
    #expect(snapshot.presentation(for: local, displayUUID: "missing").text == "Spaces unavailable")
    let shared = SpacesState.parse(
      displays: [
        ["Display Identifier": "Main", "Spaces": [["ManagedSpaceID": 50], ["ManagedSpaceID": 60]]]
      ],
      activeSpaceID: 60
    )
    #expect(shared.presentation(for: local, displayUUID: "any").text == "2 / 2")
  }

  @Test("fullscreen filtering never substitutes a desktop index for the active fullscreen Space")
  func fullscreen() {
    var item = Item(
      id: "spaces",
      type: .spaces,
      text: "{{#index}}{{index}} / {{total}}{{/index}}{{^index}}{{value}}{{/index}}",
      spaces: SpacesConfiguration(includeFullscreen: false)
    )
    #expect(snapshot.presentation(for: item).text == "Fullscreen")
    item.text = "{{#workspaces}}{{name}}{{/workspaces}}"
    let result = snapshot.presentation(for: item)
    #expect(result.segments.map(\.text) == ["1", "2", "3"])
    #expect(result.segments.allSatisfy { !$0.emphasized })
    #expect(result.accessibilityLabel.contains("Fullscreen Space active"))
    var state = snapshot
    state.focusedID = 40
    item.text = "{{#index}}{{index}} / {{total}}{{/index}}{{^index}}{{value}}{{/index}}"
    #expect(state.presentation(for: item).text == "3 / 3")
  }

  @Test("list labels and colors distinguish the active Space and respect visibility")
  func appearance() {
    var item = Item(
      id: "spaces",
      type: .spaces,
      text:
        "{{#workspaces}}{{#index=1}}Code{{/index}}{{#index=2}}Video{{/index}}{{^index=1}}{{^index=2}}{{name}}{{/index}}{{/index}}{{/workspaces}}",
      spaces: SpacesConfiguration(
        symbols: AvailabilitySymbols(font: "Shared", size: 18, available: .glyph("S")),
        tints: SpacesTints(active: "#00FF00", inactive: "#888888", unavailable: "#FF0000")
      )
    )
    let result = snapshot.presentation(for: item)
    #expect(result.symbol == .glyph("S", font: "Shared", size: 18))
    #expect(result.segments.map(\.text) == ["Code", "Video", "3", "4"])
    #expect(result.segments[1].emphasized)
    #expect(result.segments[1].tint == "#00FF00")
    #expect(result.segments[0].tint == "#888888")
    item.text = ""
    #expect(snapshot.presentation(for: item).text.isEmpty)
    #expect(snapshot.presentation(for: item).segments.isEmpty)
    #expect(snapshot.presentation(for: item).accessibilityLabel.contains("Space 2"))
    item.symbol = "star"
    #expect(snapshot.presentation(for: item).symbol == "star")
    item.spaces?.showSymbol = false
    #expect(snapshot.presentation(for: item).symbol == nil)
    #expect(SpacesState().presentation(for: item).tint == "#FF0000")
    for name in ["rectangle.3.group", "questionmark"] {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }
  }

  @Test("parser rejects booleans, negative, fractional, string, and zero IDs")
  func malformedIDs() {
    for value: Any in [true, false, -1, 1.5, "10", 0, Double.nan, Double.infinity] {
      #expect(SpacesState.identifier(value) == nil)
    }
    #expect(SpacesState.identifier(NSNumber(value: UInt64.max)) == UInt64.max)
    let state = SpacesState.parse(
      displays: [
        [
          "Display Identifier": "A", "Current Space": ["ManagedSpaceID": 999],
          "Spaces": [["ManagedSpaceID": 10], ["ManagedSpaceID": 10], ["ManagedSpaceID": -1]],
        ],
        ["Display Identifier": "B", "Spaces": [["ManagedSpaceID": 10], ["ManagedSpaceID": 20]]],
      ],
      activeSpaceID: 20
    )
    #expect(state.displays[0].spaces.count == 1)
    #expect(state.text == "2")
    #expect(!state.complete)
  }

  @Test("configuration validates labels, colors, glyphs, and source type")
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"spaces","type":"spaces","spaces":{"scope":"display","includeFullscreen":false,"showSymbol":true,"symbols":{"font":"Shared","available":{"glyph":"S"}},"tints":{"active":"#00FF00"}}}"##
          .utf8
      )
    )
    try item.spaces?.validate(path: "spaces")
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    for json in [
      #"{"scope":"invalid"}"#, #"{"tints":{"active":"red"}}"#,
      #"{"symbols":{"available":{"glyph":"S"}}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(SpacesConfiguration.self, from: Data(json.utf8))
        try settings.validate(path: "spaces")
      }
    }
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "text", type: .text, spaces: SpacesConfiguration())])
      ).validate()
    }
  }

  @Test("notification bursts coalesce, transient failures retry, and stop cancels pending work")
  func transitions() async throws {
    let workspace = NotificationCenter()
    let application = NotificationCenter()
    let valid = snapshot
    var reads = 0
    var transient = false
    var unavailable = false
    let provider = SpacesProvider(
      query: {
        reads += 1
        if unavailable { return SpacesState() }
        if transient {
          transient = false
          return SpacesState()
        }
        return valid
      },
      workspace: workspace,
      application: application
    )
    var updates: [SpacesState] = []
    provider.start { updates.append($0) }
    defer { provider.stop() }
    transient = true
    for _ in 0..<5 {
      workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }
    try await Task.sleep(for: .milliseconds(250))
    #expect(reads == 3)
    #expect(updates.count == 2)
    #expect(updates.allSatisfy { $0.complete })
    unavailable = true
    application.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    try await Task.sleep(for: .milliseconds(450))
    #expect(updates.last?.complete == false)
    #expect(reads == 7)
    workspace.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
    provider.stop()
    try await Task.sleep(for: .milliseconds(150))
    #expect(reads == 7)
  }

  @Test("manual refresh keeps the whole display snapshot until triggered")
  func refresh() throws {
    let configuration = try JSONDecoder().decode(
      Configuration.self,
      from: Data(
        #"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"spaces","type":"spaces","text":"{{#available}}{{index}} / {{total}}{{/available}}{{^available}}{{value}}{{/available}}","spaces":{"scope":"display"},"refresh":{"mode":"manual"}}]}}"#
          .utf8
      )
    )
    let runtime = ProviderRuntime()
    runtime.configure(configuration)
    defer { runtime.stop() }
    let item = try #require(configuration.items.active.first)
    runtime.updateWidgetState(.spaces(snapshot), for: .spaces)
    runtime.trigger("spaces")
    #expect(runtime.presentation(for: item, displayUUID: "display-b")?.text == "2 / 2")
    var changed = snapshot
    changed.displays[1].activeID = 30
    runtime.updateWidgetState(.spaces(changed), for: .spaces)
    #expect(runtime.presentation(for: item, displayUUID: "display-b")?.text == "2 / 2")
    runtime.trigger("spaces")
    #expect(runtime.presentation(for: item, displayUUID: "display-b")?.text == "1 / 2")
  }
}
