import Foundation
import Testing
import os

@testable import SbarCore

@Suite("Plugins")
struct PluginTests {
  @Test("PluginRunner.run: receives events and reconstructs fragmented JSON output")
  func runReceivesEventsAndReconstructsFragmentedOutput() async throws {
    let messages = OSAllocatedUnfairLock(initialState: [String]())
    let mailbox = PluginMailbox()
    mailbox.send(PluginInput(event: "refresh", value: nil))

    let script =
      #"read event; case "$event" in *refresh*) printf '{"text":'; sleep 0.02; printf '"received"}\n';; esac"#

    try await PluginRunner.run(
      configuration: .init(executable: "/bin/sh", arguments: ["-c", script], restart: false),
      mailbox: mailbox
    ) { value in
      messages.withLock { $0.append(value.text) }
    }

    #expect(messages.withLock { $0 } == ["received"])
  }

  @Test("PluginRunner.run: rejects malformed plugin output")
  func runRejectsMalformedOutput() async {
    await #expect(throws: (any Error).self) {
      try await PluginRunner.run(
        configuration: .init(
          executable: "/bin/sh",
          arguments: ["-c", "printf 'not-json\\n'"],
          restart: false
        ),
        mailbox: PluginMailbox()
      ) { _ in }
    }
  }

  @Test("PluginRunner.run: stops a quiet process when cancelled")
  func runStopsQuietProcessWhenCancelled() async throws {
    let task = Task {
      try await PluginRunner.run(
        configuration: .init(executable: "/bin/sh", arguments: ["-c", "sleep 10"], restart: false),
        mailbox: PluginMailbox()
      ) { _ in }
    }

    try await Task.sleep(for: .milliseconds(50))
    task.cancel()

    await #expect(throws: (any Error).self) { try await task.value }
  }
  @Test(
    "PluginRunner.run: wakes for input delivered after the worker becomes idle",
    .timeLimit(.minutes(1))
  )
  func runWakesForLateInput() async throws {
    let mailbox = PluginMailbox()
    let messages = OSAllocatedUnfairLock(initialState: [String]())
    let task = Task {
      try await PluginRunner.run(
        configuration: .init(
          executable: "/bin/sh",
          arguments: ["-c", #"read event; printf '{"text":"received"}\n'"#],
          restart: false
        ),
        mailbox: mailbox
      ) { value in messages.withLock { $0.append(value.text) } }
    }
    defer { task.cancel() }
    try await Task.sleep(for: .milliseconds(100))
    mailbox.send(PluginInput(event: "refresh", value: nil))
    try await task.value
    #expect(messages.withLock { $0 } == ["received"])
  }

  @Test("PluginRunner.run: drains queued input through pipe backpressure", .timeLimit(.minutes(1)))
  func runDrainsQueuedInput() async throws {
    let mailbox = PluginMailbox()
    for _ in 0..<8 {
      mailbox.send(PluginInput(event: String(repeating: "x", count: 30_000), value: nil))
    }
    let messages = OSAllocatedUnfairLock(initialState: [String]())
    try await PluginRunner.run(
      configuration: .init(
        executable: "/bin/sh",
        arguments: [
          "-c",
          #"sleep 0.05; count=0; while [ "$count" -lt 8 ]; do read event || exit 1; count=$((count + 1)); done; printf '{"text":"drained"}\n'"#,
        ],
        restart: false
      ),
      mailbox: mailbox
    ) { value in messages.withLock { $0.append(value.text) } }
    #expect(messages.withLock { $0 } == ["drained"])
  }

  @Test("PluginRunner.run: observes exit after stdout closes", .timeLimit(.minutes(1)))
  func runObservesExitAfterOutputCloses() async throws {
    try await PluginRunner.run(
      configuration: .init(
        executable: "/bin/sh",
        arguments: ["-c", "exec 1>&-; sleep 0.05"],
        restart: false
      ),
      mailbox: PluginMailbox()
    ) { _ in }
  }

}
