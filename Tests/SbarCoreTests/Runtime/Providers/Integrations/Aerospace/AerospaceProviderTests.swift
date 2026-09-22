import Foundation
import Testing

@testable import SbarCore

@Suite("AerospaceProvider")
@MainActor
struct AerospaceProviderTests {
  private var state: AerospaceState {
    AerospaceState(
      workspaces: [
        AerospaceWorkspace(name: "Code", focused: true, visible: true, monitor: 1),
        AerospaceWorkspace(name: "Web", focused: false, visible: false, monitor: 1),
        AerospaceWorkspace(name: "Chat", focused: false, visible: true, monitor: 2),
      ],
      displays: [1: "A", 2: "B"],
      unavailable: nil
    )
  }

  @Test("AerospaceState.parse: JSON rejects malformed, empty, duplicate and inconsistent snapshots")
  func parsing() throws {
    let row =
      #"{"workspace":"Code","workspace-is-focused":true,"workspace-is-visible":true,"monitor-appkit-nsscreen-screens-id":1}"#

    #expect(try AerospaceState.parse(Data("[\(row)]".utf8), displays: [1: "A"]).text == "Code")

    for json in [
      "[]", "[\(row),\(row)]", "[" + row.replacingOccurrences(of: "Code", with: " ") + "]",
    ] {
      #expect(try AerospaceState.parse(Data(json.utf8), displays: [:]).unavailable != nil)
    }
    for json in [
      "", "warning\n[\(row)]", "[{}]",
      "[" + row.replacingOccurrences(of: ":1", with: ":true") + "]",
    ] {
      #expect(throws: (any Error).self) { try AerospaceState.parse(Data(json.utf8), displays: [:]) }
    }
  }

  @Test(
    "AerospaceState.presentation(for:): named workspaces preserve focus, visibility, labels and display scope"
  )
  func presentation() {
    var item = Item(
      id: "aero",
      type: .aerospace,
      text:
        "{{#workspaces}}{{#name=Code}}Dev{{/name}}{{^name=Code}}{{name}}{{/name}}{{/workspaces}}",
      aerospace: AerospaceConfiguration(
        tints: AerospaceTints(focused: "#FFFFFF", visible: "#00FF00", inactive: "#888888")
      )
    )
    let result = state.presentation(for: item, displayUUID: nil)

    #expect(result.segments.map(\.text) == ["Dev", "Web", "Chat"])
    #expect(result.segments.map(\.emphasized) == [true, false, false])
    #expect(result.segments[2].tint == "#00FF00")

    item.aerospace?.scope = .display
    item.text = nil

    #expect(state.presentation(for: item, displayUUID: "b").text == "Chat")
    #expect(state.presentation(for: item, displayUUID: "missing").text == "Aerospace unavailable")

    item.text = ""
    item.symbol = "star"

    #expect(state.presentation(for: item, displayUUID: "A").text.isEmpty)
    #expect(state.presentation(for: item, displayUUID: "A").symbol == "star")

    item.aerospace?.showSymbol = false

    #expect(state.presentation(for: item, displayUUID: "A").symbol == nil)
  }

  @Test(
    "AerospaceConfiguration.validate: configuration roundtrips and rejects invalid provider options"
  )
  func configuration() throws {
    let item = Item(
      id: "aero",
      type: .aerospace,
      text:
        "{{#workspaces}}{{#name=Code}}Dev{{/name}}{{^name=Code}}{{name}}{{/name}}{{/workspaces}}",
      aerospace: AerospaceConfiguration(scope: .display)
    )

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    for json in [
      #"{"scope":"bad"}"#, #"{"tints":{"focused":"red"}}"#,
      #"{"symbols":{"available":{"glyph":"A"}}}"#,
    ] {
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(AerospaceConfiguration.self, from: Data(json.utf8)).validate(
          path: "aerospace"
        )
      }
    }

    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "bad", type: .text, aerospace: .init())])
      ).validate()
    }
  }

  @Test(
    "AerospaceProvider.start: refresh bursts coalesce, cancellation suppresses stale results, and failures recover"
  )
  func lifecycle() async throws {
    let valid = state
    var reads = 0
    var suspended: CheckedContinuation<AerospaceState, Never>?
    let provider = AerospaceProvider(read: {
      reads += 1

      if reads == 1 { return await withCheckedContinuation { suspended = $0 } }

      return reads == 2 ? AerospaceState() : valid
    })
    var updates: [AerospaceState] = []
    provider.start { updates.append($0) }
    defer {
      suspended?.resume(returning: valid)
      provider.stop()
    }

    for _ in 0..<5 { provider.requestRefresh() }

    try await waitUntil { suspended != nil }
    provider.requestRefresh()
    try await waitUntil { updates.count == 1 }

    #expect(reads == 2)
    #expect(updates.count == 1)
    #expect(updates.last?.unavailable != nil)

    suspended?.resume(returning: valid)
    suspended = nil
    provider.requestRefresh()
    try await waitUntil { updates.last == valid }

    #expect(updates.count == 2)
    #expect(updates.last == valid)

    provider.requestRefresh()
    provider.stop()
    try await Task.sleep(for: .milliseconds(180))

    #expect(reads == 3)
  }

  @Test(
    "AerospaceProvider.start: provider stdout excludes stderr while existing process callers retain merged output"
  )
  func standardError() async throws {
    let result = try await ProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "printf 'Code'; printf 'diagnostic' >&2"],
      mergeStandardError: false
    )

    #expect(result.output == "Code")

    let merged = try await ProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "printf 'diagnostic' >&2"]
    )

    #expect(merged.output == "diagnostic")
  }

  @Test("ProviderRuntime.trigger: manual triggers capture a newly queried snapshot")
  func trigger() async throws {
    var current = state
    let runtime = ProviderRuntime(aerospace: AerospaceProvider(read: { current }))
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(#"{"id":"aero","type":"aerospace","refresh":{"mode":"manual"}}"#.utf8)
    )
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }
    try await waitUntil { runtime.presentation(for: item)?.text == "Code" }

    current.workspaces[0].focused = false
    current.workspaces[0].visible = false
    current.workspaces[1].focused = true
    current.workspaces[1].visible = true
    runtime.trigger("aero")

    #expect(runtime.presentation(for: item)?.text == "Code")

    try await waitUntil { runtime.presentation(for: item)?.text == "Web" }
  }
}
