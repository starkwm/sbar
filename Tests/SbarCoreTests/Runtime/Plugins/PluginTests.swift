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
      messages.withLock { $0.append(value) }
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
}
