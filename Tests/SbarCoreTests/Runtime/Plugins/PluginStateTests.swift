import Foundation
import Testing

@testable import SbarCore

@Suite("PluginState")
@MainActor
struct PluginStateTests {
  @Test("PluginState.restartDelay: only sustained runs with valid output reset backoff")
  func backoff() {
    #expect(PluginState.restartDelay(30, uptime: .seconds(30), receivedOutput: true) == 1)
    #expect(PluginState.restartDelay(30, uptime: .seconds(29), receivedOutput: true) == 30)
    #expect(PluginState.restartDelay(30, uptime: .seconds(60), receivedOutput: false) == 30)
  }

  @Test(
    "PluginState.presentation: structured appearance and errors preserve text-only compatibility"
  )
  func appearance() throws {
    var framer = PluginOutputFramer()
    let decoded = try framer.append(
      Data(
        ##"{"text":"hello\nworld","symbol":{"glyph":"X","font":"Menlo"},"tint":"#00FF00","hidden":true}"##
          .utf8
      ) + Data([10])
    )
    let value = try #require(decoded)
    var item = Item(
      id: "plugin",
      type: .plugin,
      plugin: Plugin(executable: "/bin/sh", maxLength: 8, onError: .keepLast)
    )
    let state = PluginState(status: .success, lastSuccess: value)

    #expect(state.presentation(for: item).text == "hello w…")
    #expect(state.presentation(for: item).hidden)
    #expect(state.presentation(for: item).symbol == .glyph("X", font: "Menlo"))

    item.symbol = "star"

    #expect(state.presentation(for: item).symbol == "star")

    let failed = PluginState(status: .failure, lastSuccess: value, error: "failed")

    #expect(failed.presentation(for: item).text == "hello w…")

    item.plugin?.onError = .show

    #expect(failed.presentation(for: item).text == "failed")
    #expect(!failed.presentation(for: item).hidden)

    item.plugin?.onError = .hide

    #expect(failed.presentation(for: item).hidden)
  }

  @Test(
    "PluginOutputFramer.append: line boundaries apply per message, including a full line followed by another message"
  )
  func framing() throws {
    let line = "{\"text\":\"" + String(repeating: "a", count: 65_525) + "\"}"

    #expect(line.utf8.count == 65_536)

    var framer = PluginOutputFramer()

    #expect(try framer.append(Data(line.prefix(65_000).utf8)) == nil)

    let result = try framer.append(Data((line.dropFirst(65_000) + "\n{\"text\":\"last\"}\n").utf8))

    #expect(result?.text == "last")

    try framer.finish()
    var oversized = PluginOutputFramer()

    #expect(throws: PluginProtocolError.lineLimit) {
      try oversized.append(Data(repeating: 97, count: 65_537))
    }

    var unfinished = PluginOutputFramer()
    _ = try unfinished.append(Data("{\"text\":\"x\"}".utf8))

    #expect(throws: PluginProtocolError.unterminatedMessage) { try unfinished.finish() }

    var invalid = PluginOutputFramer()

    #expect(throws: PluginProtocolError.invalidMessage) { try invalid.append(Data([255, 10])) }
  }

  @Test("PluginMailbox.send: mailbox retains its first start event under saturation")
  func mailbox() throws {
    let box = PluginMailbox()
    box.send(PluginInput(event: "start", value: nil))

    for _ in 0..<100 { box.send(PluginInput(event: "trigger", value: nil)) }

    let first = try #require(box.take())

    #expect(try JSONDecoder().decode(PluginInput.self, from: first).event == "start")

    var remaining = 0

    while box.take() != nil { remaining += 1 }

    #expect(remaining == 31)
  }

  @Test(
    "ProviderRuntime.configure: execution changes restart only the affected plugin and appearance changes retain state"
  )
  func reconciliation() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let script = "printf x >> '\(file.path)'; printf '{\"text\":\"ready\"}\\n'; sleep 10"
    var first = Item(
      id: "first",
      type: .plugin,
      plugin: Plugin(executable: "/bin/sh", arguments: ["-c", script], restart: false)
    )
    var second = Item(
      id: "second",
      type: .plugin,
      plugin: Plugin(executable: "/bin/sh", arguments: ["-c", "sleep 10"], restart: false)
    )
    let runtime = ProviderRuntime()
    runtime.configure(Configuration(bar: .init(), items: .init(right: [first, second])))
    defer { runtime.stop() }

    for _ in 0..<100 where runtime.pluginStates["first"]?.status != .success {
      try await Task.sleep(for: .milliseconds(10))
    }

    first.plugin?.maxLength = 3
    second.plugin?.arguments = ["-c", "printf '{\"text\":\"changed\"}\\n'"]
    runtime.configure(Configuration(bar: .init(), items: .init(right: [first, second])))

    for _ in 0..<100 where runtime.pluginStates["second"]?.status != .success {
      try await Task.sleep(for: .milliseconds(10))
    }

    #expect(try String(contentsOf: file, encoding: .utf8) == "x")
    #expect(runtime.presentation(for: first)?.text == "re…")
    #expect(runtime.itemValues["second"] == "changed")

    runtime.configure(Configuration(bar: .init(), items: .init()))
    try await Task.sleep(for: .milliseconds(50))

    #expect(runtime.pluginStates.isEmpty)
    #expect(runtime.itemValues["first"] == nil)
  }

  @Test(
    "ProviderRuntime.configure: restart receives start first and late success cannot overwrite exit failure"
  )
  func restart() async throws {
    let item = Item(
      id: "plugin",
      type: .plugin,
      plugin: Plugin(
        executable: "/bin/sh",
        arguments: [
          "-c",
          #"read event; case "$event" in *start*) printf '{"text":"started"}\n';; *) printf '{"text":"wrong"}\n';; esac; sleep 0.05; exit 7"#,
        ]
      )
    )
    var delays: [Duration] = []
    var pendingRestart: CheckedContinuation<Void, any Error>?
    let runtime = ProviderRuntime(pluginRestartSleep: { delay in
      delays.append(delay)
      try await withCheckedThrowingContinuation { pendingRestart = $0 }
    })
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    defer {
      runtime.stop()
      pendingRestart?.resume(throwing: CancellationError())
    }
    try await waitUntil { pendingRestart != nil }

    #expect(delays == [.seconds(1)])
    #expect(runtime.pluginStates[item.id]?.status == .failure)
    #expect(runtime.pluginStates[item.id]?.lastSuccess?.text == "started")

    for _ in 0..<40 { runtime.trigger("queued") }

    let restart = try #require(pendingRestart)
    pendingRestart = nil
    restart.resume()
    try await waitUntil { pendingRestart != nil }

    #expect(delays == [.seconds(1), .seconds(2)])
    #expect(runtime.pluginStates[item.id]?.lastSuccess?.text == "started")
    #expect(runtime.pluginStates[item.id]?.status == .failure)
    #expect(runtime.itemValues[item.id] == "Process exited with status 7.")
  }

  @Test("Plugin.validate: plugin configuration rejects blank executables and mismatched item types")
  func validation() throws {
    #expect(throws: ConfigurationError.self) {
      try Plugin(executable: " \n").validate(path: "plugin")
    }
    #expect(throws: ConfigurationError.self) {
      try Plugin(executable: "/bin/sh", maxLength: 0).validate(path: "plugin")
    }
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "bad", type: .text, plugin: Plugin(executable: "/bin/sh"))])
      ).validate()
    }
  }
}
