import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("SpacesState")
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

  @Test("presentation(for:): scope preserves global order and each display's current Space")
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

  @Test(
    "presentation(for:): fullscreen filtering never substitutes a desktop index for the active fullscreen Space"
  )
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

  @Test(
    "presentation(for:): list labels and colors distinguish the active Space and respect visibility"
  )
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
  }

  @Test(
    "presentation(for:): name overrides apply to current labels and lists without changing identity or styling"
  )
  func names() {
    var item = Item(
      id: "spaces",
      type: .spaces,
      spaces: SpacesConfiguration(
        names: ["Code", "\u{f121}", "{{index}}"],
        tints: SpacesTints(active: "#00FF00", inactive: "#888888")
      )
    )

    #expect(snapshot.presentation(for: item).text == "\u{f121}")

    item.text = "{{name}}|{{value}}|{{index}}|{{workspaceId}}"

    #expect(snapshot.presentation(for: item).text == "\u{f121}|\u{f121}|2|20")

    item.text = "{{#workspaces}}{{name}}{{/workspaces}}"
    let result = snapshot.presentation(for: item)

    #expect(result.segments.map(\.text) == ["Code", "\u{f121}", "{{index}}", "4"])
    #expect(result.segments[1].emphasized)
    #expect(result.segments[1].tint == "#00FF00")
    #expect(result.segments[0].tint == "#888888")

    item.text = "{{#workspaces}}{{value}}{{/workspaces}}"

    #expect(snapshot.presentation(for: item).text == result.text)

    item.text = "{{#index=2}}Custom{{/index}}"

    #expect(snapshot.presentation(for: item).text == "Custom")
  }

  @Test("presentation(for:): name positions follow display scope and fullscreen filtering")
  func scopedNames() {
    var item = Item(
      id: "spaces",
      type: .spaces,
      spaces: SpacesConfiguration(names: ["Code", "Web", "Chat"], includeFullscreen: false)
    )

    #expect(snapshot.presentation(for: item).text == "Fullscreen")

    item.text = "{{#workspaces}}{{name}}:{{workspaceId}};{{/workspaces}}"

    #expect(snapshot.presentation(for: item).text == "Code:10;Web:30;Chat:40;")

    item.spaces?.scope = .display

    #expect(snapshot.presentation(for: item, displayUUID: "display-b").text == "Code:30;Web:40;")

    item.text = nil
    let local = snapshot.presentation(for: item, displayUUID: "display-b")

    #expect(local.text == "Web")
    #expect(local.accessibilityLabel == "Space Web, 2 of 2")
    #expect(SpacesState().presentation(for: item).text == "Spaces unavailable")
  }

  @Test(
    "presentation(for:): missing, null, and empty names retain default numbers and extra names are ignored"
  )
  func nameFallbacks() {
    var item = Item(
      id: "spaces",
      type: .spaces,
      text: "{{#workspaces}}{{name}}{{#separator}},{{/separator}}{{/workspaces}}"
    )

    for names: [SpaceName?]? in [nil, [], [nil, ""], ["", nil, "", nil, "Unused"]] {
      item.spaces = SpacesConfiguration(names: names)

      #expect(snapshot.presentation(for: item).text == "1,2,3,4")
    }
  }

  @Test(
    "presentation(for:): symbol name overrides render current and mixed list labels with active styling"
  )
  func symbolNames() {
    let glyph = ItemSymbol.glyph("\u{f121}", font: "Symbols Nerd Font Mono", size: 16)
    var item = Item(
      id: "spaces",
      type: .spaces,
      spaces: SpacesConfiguration(
        names: ["Code", .symbol("globe"), nil, .symbol(glyph)],
        tints: SpacesTints(active: "#00FF00", inactive: "#888888"),
        showSymbol: false
      )
    )
    let current = snapshot.presentation(for: item)

    #expect(current.symbol == nil)
    #expect(current.segments.map(\.text) == [""])
    #expect(current.segments.map(\.symbol) == ["globe"])
    #expect(current.segments.first?.tint == "#00FF00")
    #expect(current.accessibilityLabel == "Space 2, 2 of 4")

    for field in ["name", "value"] {
      item.text = "{{#workspaces}}{{\(field)}}{{#separator}} · {{/separator}}{{/workspaces}}"
      let list = snapshot.presentation(for: item)

      #expect(list.segments.map(\.text) == ["Code", " · ", "", " · ", "3", " · ", ""])
      #expect(list.segments.map(\.symbol) == [nil, nil, "globe", nil, nil, nil, glyph])
      #expect(list.segments.map(\.emphasized) == [false, false, true, false, false, false, false])
      #expect(list.segments[2].tint == "#00FF00")
      #expect(list.segments[1].tint == "#888888")
      #expect(list.segments[6].tint == "#888888")
      #expect(list.segmentSpacing == 0)
    }

    item.spaces?.showSymbol = true
    item.symbol = "star"

    #expect(snapshot.presentation(for: item).symbol == "star")

    item.text = nil

    #expect(snapshot.presentation(for: item).tint == "#00FF00")
    #expect(snapshot.presentation(for: item).segments.first?.symbol == "globe")

    item.text = ""

    #expect(snapshot.presentation(for: item).segments.isEmpty)
    #expect(snapshot.presentation(for: item).symbol == "star")
  }

  @Test(
    "presentation(for:): symbol substitutions preserve template literals, identity fields, conditions, and order"
  )
  func symbolTemplates() {
    var item = Item(
      id: "spaces",
      type: .spaces,
      text: "2[{{name}}]{{index}}/{{workspaceId}}={{value}}",
      spaces: SpacesConfiguration(names: [nil, .symbol("globe")])
    )
    let current = snapshot.presentation(for: item)

    #expect(current.segments.map(\.text) == ["2[", "", "]2/20=", ""])
    #expect(current.segments.map(\.symbol) == [nil, "globe", nil, "globe"])

    item.text =
      "{{#workspaces}}{{#active}}{{name}}{{/active}}{{#separator}} · {{/separator}}{{/workspaces}}"
    let filtered = snapshot.presentation(for: item)

    #expect(filtered.segments.count == 1)
    #expect(filtered.segments.first?.symbol == "globe")

    item.text = "{{#name=2}}{{name}}{{/name}}{{^name=2}}Other{{/name}}"

    #expect(snapshot.presentation(for: item).segments.first?.symbol == "globe")

    item.text = "{{index}}"

    #expect(snapshot.presentation(for: item).text == "2")
    #expect(snapshot.presentation(for: item).segments.isEmpty)

    item.text = "{{#index=99}}{{name}}{{/index}}"

    #expect(snapshot.presentation(for: item).segments.isEmpty)
    #expect(snapshot.presentation(for: item).text.isEmpty)

    item.spaces?.names = ["Code", .symbol("globe")]
    item.text = "{{#workspaces}}[{{name}}]{{/workspaces}}"
    let mixed = snapshot.presentation(for: item)

    #expect(mixed.segments.map(\.text) == ["[Code]", "[", "", "]", "[3]", "[4]"])
    #expect(mixed.segments.map(\.symbol) == [nil, nil, "globe", nil, nil, nil])
  }

  @Test(
    "presentation(for:): symbol overrides follow scoped filtered positions and unavailable fallbacks"
  )
  func scopedSymbolNames() {
    var item = Item(
      id: "spaces",
      type: .spaces,
      spaces: SpacesConfiguration(
        names: [.symbol("terminal"), .symbol("globe")],
        includeFullscreen: false
      )
    )

    #expect(snapshot.presentation(for: item).text == "Fullscreen")
    #expect(snapshot.presentation(for: item).segments.isEmpty)

    item.text = "{{#workspaces}}{{name}}{{/workspaces}}{{^workspaces}}{{value}}{{/workspaces}}"

    #expect(snapshot.presentation(for: item).segments.map(\.symbol) == ["terminal", "globe", nil])

    item.spaces?.scope = .display

    #expect(
      snapshot.presentation(for: item, displayUUID: "display-b").segments.map(\.symbol) == [
        "terminal", "globe",
      ]
    )

    let unavailable = SpacesState().presentation(for: item)

    #expect(unavailable.text == "Spaces unavailable")
    #expect(unavailable.segments.isEmpty)
  }

  @Test(
    "SpacesConfiguration.init(from:): symbol names decode and roundtrip alongside text and reject malformed symbols"
  )
  func symbolNameConfiguration() throws {
    let json =
      #"{"names":["globe",{"symbol":"globe"},{"symbol":{"glyph":"\uf121","font":"Symbols Nerd Font Mono","size":16}},null,""]}"#
    let settings = try JSONDecoder().decode(SpacesConfiguration.self, from: Data(json.utf8))

    #expect(
      settings.names == [
        .text("globe"), .symbol("globe"),
        .symbol(.glyph("\u{f121}", font: "Symbols Nerd Font Mono", size: 16)), nil, .text(""),
      ]
    )
    #expect(
      try JSONDecoder().decode(SpacesConfiguration.self, from: JSONEncoder().encode(settings))
        == settings
    )

    for value in [
      "{}", #"{"symbol":null}"#, #"{"symbol":1}"#, #"{"symbol":" "}"#,
      #"{"symbol":{"glyph":"x"}}"#, #"{"symbol":{"glyph":"x","font":"Mono","size":1}}"#,
    ] {
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(
          SpacesConfiguration.self,
          from: Data("{\"names\":[\(value)]}".utf8)
        )
      }
    }
  }

  @Test("SpacesState.parse: parser rejects booleans, negative, fractional, string, and zero IDs")
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

  @Test(
    "SpacesConfiguration.validate: configuration validates labels, colors, glyphs, and source type"
  )
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"spaces","type":"spaces","spaces":{"scope":"display","names":["Code",null,"","\uf121"],"includeFullscreen":false,"showSymbol":true,"symbols":{"font":"Shared","available":{"glyph":"S"}},"tints":{"active":"#00FF00"}}}"##
          .utf8
      )
    )
    try item.spaces?.validate(path: "spaces")

    #expect(item.spaces?.names == ["Code", nil, "", "\u{f121}"])
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    for json in [
      #"{"scope":"invalid"}"#, #"{"tints":{"active":"red"}}"#,
      #"{"symbols":{"available":{"glyph":"S"}}}"#,
      #"{"names":"Code"}"#, #"{"names":[1]}"#, #"{"names":[true]}"#,
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

  @Test(
    "SpacesProvider.start: notification bursts coalesce, transient failures retry, and stop cancels pending work"
  )
  func transitions() async throws {
    let workspace = NotificationCenter()
    let application = NotificationCenter()
    let valid = snapshot
    let query = QueryState()
    let provider = SpacesProvider(
      query: {
        query.reads += 1

        if query.unavailable { return SpacesState() }
        if query.transient {
          query.transient = false

          return SpacesState()
        }

        return valid
      },
      workspace: workspace,
      application: application,
      retryInterval: .milliseconds(5)
    )
    var updates: [SpacesState] = []
    provider.start { updates.append($0) }
    defer { provider.stop() }
    query.transient = true

    for _ in 0..<5 {
      workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    try await waitUntil { updates.count == 2 }

    #expect(query.reads == 3)
    #expect(updates.count == 2)
    #expect(updates.allSatisfy { $0.complete })

    query.unavailable = true
    application.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    try await waitUntil { updates.last?.complete == false }

    #expect(updates.last?.complete == false)
    #expect(query.reads == 7)

    workspace.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
    provider.stop()
    try await Task.sleep(for: .milliseconds(150))

    #expect(query.reads == 7)
  }

  @Test(
    "ProviderRuntime.presentation(for:): manual refresh keeps the whole display snapshot until triggered"
  )
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

@MainActor
private final class QueryState {
  var reads = 0
  var transient = false
  var unavailable = false
}
