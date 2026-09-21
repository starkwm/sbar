import Foundation
import Testing

@testable import SbarCore

@Suite("Yabai")
@MainActor
struct YabaiProviderTests {
  private var state: YabaiState {
    YabaiState(
      workspaces: [
        YabaiWorkspace(
          id: 10,
          index: 1,
          label: "Code",
          focused: true,
          visible: true,
          monitor: 2,
          fullscreen: false
        ),
        YabaiWorkspace(
          id: 20,
          index: 2,
          label: " ",
          focused: false,
          visible: false,
          monitor: 2,
          fullscreen: true
        ),
        YabaiWorkspace(
          id: 30,
          index: 3,
          label: nil,
          focused: false,
          visible: true,
          monitor: 1,
          fullscreen: false
        ),
      ],
      displays: [2: "A", 1: "B"],
      unavailable: nil
    )
  }

  @Test("display mapping, native labels and fullscreen filtering retain Mission Control indexes")
  func presentation() {
    var item = Item(
      id: "yabai",
      type: .yabai,
      text: "{{#workspaces}}{{name}}{{/workspaces}}",
      yabai: YabaiConfiguration(
        includeFullscreen: false,
        tints: YabaiTints(focused: "#FFFFFF", visible: "#00FF00", inactive: "#888888")
      )
    )
    let result = state.presentation(for: item, displayUUID: nil)
    #expect(result.segments.map(\.text) == ["Code", "3"])
    #expect(result.segments[0].emphasized)
    #expect(result.segments[1].tint == "#00FF00")
    item.yabai?.scope = .display
    item.text = nil
    #expect(state.presentation(for: item, displayUUID: "b").text == "3")
    #expect(state.presentation(for: item, displayUUID: "missing").text == "Yabai unavailable")
    var fullscreen = state
    fullscreen.workspaces[0].focused = false
    fullscreen.workspaces[0].visible = false
    fullscreen.workspaces[1].focused = true
    fullscreen.workspaces[1].visible = true
    #expect(fullscreen.presentation(for: item, displayUUID: "A").text == "Fullscreen")
    item.text = "{{#workspaces}}{{name}}{{/workspaces}}"
    #expect(fullscreen.presentation(for: item, displayUUID: "A").segments.map(\.text) == ["Code"])
    #expect(
      fullscreen.presentation(for: item, displayUUID: "A").segments.allSatisfy { !$0.emphasized }
    )
    item.text = ""
    item.symbol = "star"
    #expect(state.presentation(for: item, displayUUID: "A").text.isEmpty)
    #expect(state.presentation(for: item, displayUUID: "A").segments.isEmpty)
    #expect(state.presentation(for: item, displayUUID: "A").symbol == "star")
    item.yabai?.showSymbol = false
    #expect(state.presentation(for: item, displayUUID: "A").symbol == nil)
  }

  @Test("JSON validates identifiers, focus, display joins and whitespace label fallback")
  func parsing() throws {
    let row =
      #"{"id":10,"index":3,"label":" ","has-focus":true,"is-visible":true,"display":2,"is-native-fullscreen":false}"#
    let displays = [YabaiDisplay(uuid: "A", index: 2)]
    #expect(try YabaiState.parse(Data("[\(row)]".utf8), displays: displays).text == "3")
    for json in [
      "[]", "[\(row),\(row)]",
      "[" + row.replacingOccurrences(of: "\"index\":3", with: "\"index\":0") + "]",
      "[" + row.replacingOccurrences(of: "\"display\":2", with: "\"display\":1") + "]",
    ] {
      #expect(try YabaiState.parse(Data(json.utf8), displays: displays).unavailable != nil)
    }
    for json in [
      "", "warning\n[\(row)]", "[{}]",
      "[" + row.replacingOccurrences(of: "\"id\":10", with: "\"id\":true") + "]",
      "[" + row.replacingOccurrences(of: "\"id\":10", with: "\"id\":-1") + "]",
    ] {
      #expect(throws: (any Error).self) {
        try YabaiState.parse(Data(json.utf8), displays: displays)
      }
    }
    #expect(
      try YabaiState.parse(Data("[\(row)]".utf8), displays: displays + displays).unavailable != nil
    )
  }

  @Test("configuration validates and roundtrips")
  func configuration() throws {
    let item = Item(
      id: "yabai",
      type: .yabai,
      text: "{{#workspaces}}{{name}}{{/workspaces}}",
      yabai: YabaiConfiguration(scope: .display, includeFullscreen: false)
    )
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    for json in [
      #"{"scope":"bad"}"#, #"{"tints":{"focused":"red"}}"#,
      #"{"symbols":{"available":{"glyph":"Y"}}}"#,
    ] {
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(YabaiConfiguration.self, from: Data(json.utf8)).validate(
          path: "yabai"
        )
      }
    }
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "bad", type: .text, yabai: .init())])
      ).validate()
    }
  }

  @Test("bursts coalesce, transient reads retry and persistent failures replace the snapshot")
  func retries() async throws {
    let valid = state
    let queryState = TestYabaiQueryState()
    let provider = YabaiProvider(
      retryInterval: .milliseconds(5),
      read: {
        queryState.reads += 1
        return queryState.fail || queryState.reads == 1 ? YabaiState() : valid
      }
    )
    var updates: [YabaiState] = []
    provider.start { updates.append($0) }
    defer { provider.stop() }
    for _ in 0..<5 { provider.requestRefresh() }
    try await waitUntil { updates == [valid] }
    #expect(queryState.reads == 2)
    #expect(updates == [valid])
    queryState.fail = true
    provider.requestRefresh()
    try await waitUntil { updates.last?.unavailable != nil }
    #expect(queryState.reads == 5)
    #expect(updates.last?.unavailable != nil)
    provider.requestRefresh()
    provider.stop()
    try await Task.sleep(for: .milliseconds(100))
    #expect(queryState.reads == 5)
  }

  @Test("superseded in-flight reads cannot publish, and providers restart")
  func cancellation() async throws {
    let valid = state
    var reads = 0
    var suspended: CheckedContinuation<YabaiState, Never>?
    let provider = YabaiProvider(read: {
      reads += 1
      if reads == 1 { return await withCheckedContinuation { suspended = $0 } }
      return valid
    })
    var updates = 0
    provider.start { _ in updates += 1 }
    defer {
      suspended?.resume(returning: valid)
      provider.stop()
    }
    for _ in 0..<100 where suspended == nil { try await Task.sleep(for: .milliseconds(10)) }
    #expect(suspended != nil)
    provider.requestRefresh()
    for _ in 0..<100 where updates == 0 { try await Task.sleep(for: .milliseconds(10)) }
    #expect(reads == 2)
    #expect(updates == 1)
    suspended?.resume(returning: valid)
    suspended = nil
    try await Task.sleep(for: .milliseconds(50))
    #expect(updates == 1)
    provider.stop()
    provider.start { _ in updates += 1 }
    for _ in 0..<100 where updates == 1 { try await Task.sleep(for: .milliseconds(10)) }
    #expect(updates == 2)
  }

  @Test("manual and event triggers query fresh state before capture")
  func triggers() async throws {
    var current = state
    let runtime = ProviderRuntime(yabai: YabaiProvider(read: { current }))
    let manual = try JSONDecoder().decode(
      Item.self,
      from: Data(#"{"id":"manual","type":"yabai","refresh":{"mode":"manual"}}"#.utf8)
    )
    let event = try JSONDecoder().decode(
      Item.self,
      from: Data(
        #"{"id":"event","type":"yabai","refresh":{"mode":"event","event":"changed"}}"#.utf8
      )
    )
    runtime.configure(Configuration(bar: .init(), items: .init(right: [manual, event])))
    defer { runtime.stop() }
    try await waitUntil { runtime.presentation(for: manual)?.text == "Code" }
    #expect(runtime.presentation(for: manual)?.text == "Code")
    current.workspaces[0].label = "Work"
    runtime.trigger("manual")
    runtime.trigger("changed")
    #expect(runtime.presentation(for: manual)?.text == "Code")
    try await waitUntil { runtime.presentation(for: event)?.text == "Work" }
    #expect(runtime.presentation(for: manual)?.text == "Work")
    #expect(runtime.presentation(for: event)?.text == "Work")
  }
}

@MainActor
private final class TestYabaiQueryState {
  var reads = 0
  var fail = false
}
