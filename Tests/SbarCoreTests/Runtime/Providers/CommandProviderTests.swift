import Foundation
import Testing

@testable import SbarCore

@Suite("Shell command provider")
@MainActor
struct CommandProviderTests {
  @Test("JSON supports symbols, glyphs, tint and visibility and rejects malformed output")
  func json() throws {
    let settings = ShellCommand(script: "test", format: .json)
    let value = try CommandState.decode(
      ##"{"text":"3 updates","symbol":"shippingbox.fill","tint":"#FFCC00","hidden":true}"##,
      configuration: settings
    )
    #expect(value.symbol == "shippingbox.fill")
    var item = Item(id: "cmd", type: .command, command: settings)
    let state = CommandState(status: .success, lastSuccess: value)
    #expect(state.presentation(for: item).hidden)
    #expect(state.presentation(for: item).tint == "#FFCC00")
    item.symbol = "star"
    #expect(state.presentation(for: item).symbol == "star")
    item.command?.showSymbol = false

    #expect(state.presentation(for: item).symbol == nil)
    #expect(state.presentation(for: item).text == "3 updates")
    let glyph = try CommandState.decode(
      #"{"text":"ok","symbol":{"glyph":"X","font":"Menlo","size":14}}"#,
      configuration: settings
    )
    #expect(glyph.symbol == .glyph("X", font: "Menlo", size: 14))
    for output in [
      "", "[]", "{}", #"{"text":2}"#, #"{"text":"x","tint":"red"}"#,
      #"{"text":"x","symbol":{"glyph":"X"}}"#,
    ] {
      #expect(throws: (any Error).self) { try CommandState.decode(output, configuration: settings) }
    }
  }

  @Test("presentation normalizes lines, limits characters and applies failure policies")
  func presentation() {
    var item = Item(
      id: "cmd",
      type: .command,
      command: ShellCommand(script: "test", maxLength: 5, onError: .keepLast)
    )
    let state = CommandState(
      status: .failure,
      lastSuccess: CommandValue(text: "abc\ndefgh"),
      error: "failed"
    )
    #expect(state.presentation(for: item).text == "abc …")
    item.command?.onError = .show
    #expect(state.presentation(for: item).text == "fail…")
    item.command?.onError = .hide
    #expect(state.presentation(for: item).hidden)
    #expect(CommandState.displayText(" \n\t ", limit: 10) == "")
    #expect(CommandState.displayText("abc", limit: 1) == "…")
  }

  @Test("configuration rejects blank scripts, invalid limits and incompatible options")
  func configuration() throws {
    for command in [
      ShellCommand(script: " \n"), ShellCommand(script: "x", maxLength: 0),
      ShellCommand(script: "x", output: .combined, format: .json),
    ] {
      #expect(throws: ConfigurationError.self) { try command.validate(path: "command") }
    }
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "bad", type: .text, command: ShellCommand(script: "x"))])
      ).validate()
    }
    let command = ShellCommand(
      script: "x",
      format: .json,
      onError: .keepLast,
      symbols: CommandSymbols(success: .system("star"))
    )
    #expect(
      try JSONDecoder().decode(ShellCommand.self, from: JSONEncoder().encode(command)) == command
    )
  }

  @Test("execution handles stderr, nonzero exits, empty output and invalid JSON")
  func execution() async throws {
    let items = [
      Item(
        id: "stdout",
        type: .command,
        command: ShellCommand(script: "printf ok; printf warning >&2", output: .stdout)
      ),
      Item(id: "combined", type: .command, command: ShellCommand(script: "printf warning >&2")),
      Item(id: "failure", type: .command, command: ShellCommand(script: "printf broken; exit 7")),
      Item(id: "empty", type: .command, command: ShellCommand(script: "true")),
      Item(
        id: "json",
        type: .command,
        command: ShellCommand(
          script: "printf '{\"text\":\"ok\",\"symbol\":\"star\"}'; printf warning >&2",
          format: .json
        )
      ),
      Item(
        id: "invalid",
        type: .command,
        command: ShellCommand(script: "printf broken", format: .json)
      ),
    ]
    let runtime = ProviderRuntime()
    runtime.configure(Configuration(bar: .init(), items: .init(right: items)))
    defer { runtime.stop() }
    for _ in 0..<200
    where items.contains(where: {
      runtime.commandStates[$0.id]?.status == nil
        || runtime.commandStates[$0.id]?.status == .running
    }) {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(runtime.itemValues["stdout"] == "ok")
    #expect(runtime.itemValues["combined"] == "warning")
    #expect(runtime.itemValues["failure"] == "Exit 7: broken")
    #expect(runtime.itemValues["empty"] == "")
    #expect(runtime.presentation(for: items[4])?.symbol == "star")
    #expect(runtime.commandStates["invalid"]?.status == .failure)
  }

  @Test("triggers coalesce and failed reruns retain success without cosmetic reexecution")
  func retention() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    var item = Item(
      id: "cmd",
      type: .command,
      command: ShellCommand(
        script:
          "if test -f '\(file.path)'; then printf run >> '\(file.path)'; exit 2; fi; printf run > '\(file.path)'; printf ready",
        onError: .keepLast
      )
    )
    let runtime = ProviderRuntime()
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }
    for _ in 0..<100 where runtime.commandStates[item.id]?.status != .success {
      try await Task.sleep(for: .milliseconds(10))
    }
    item.command?.maxLength = 3
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    #expect(runtime.commandStates[item.id]?.status == .success)
    #expect(runtime.presentation(for: item)?.text == "re…")
    for _ in 0..<5 { runtime.trigger(item.id) }
    for _ in 0..<100 where runtime.commandStates[item.id]?.status != .failure {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(runtime.commandStates[item.id]?.status == .failure)
    #expect(try String(contentsOf: file, encoding: .utf8) == "runrun")
    #expect(runtime.presentation(for: item)?.text == "re…")
    item.command?.onError = .show
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    #expect(runtime.presentation(for: item)?.text == "Ex…")
    runtime.configure(Configuration(bar: .init(), items: .init()))
    #expect(runtime.commandStates.isEmpty)
  }

  @Test("timeouts recover on replacement and removed commands cannot publish")
  func cancellation() async throws {
    var item = Item(
      id: "cmd",
      type: .command,
      command: ShellCommand(script: "sleep 1; printf stale", timeout: 0.1)
    )
    let runtime = ProviderRuntime()
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }
    for _ in 0..<100 where runtime.commandStates[item.id]?.status != .failure {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(runtime.itemValues[item.id] == "Command timed out.")
    item.command?.script = "printf recovered"
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    for _ in 0..<100 where runtime.commandStates[item.id]?.status != .success {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(runtime.itemValues[item.id] == "recovered")
    item.command?.script = "sleep 0.1; printf stale"
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    runtime.configure(Configuration(bar: .init(), items: .init()))
    try await Task.sleep(for: .milliseconds(180))
    #expect(runtime.itemValues[item.id] == nil)
  }
}
