import Foundation
import os
import Testing
@testable import StarkBar

struct PluginTests {
    @Test("Plugins receive events and reconstruct fragmented JSON output")
    func stream() async throws {
        let messages = OSAllocatedUnfairLock(initialState: [String]())
        let mailbox = PluginMailbox()
        mailbox.send(PluginInput(event: "refresh", value: nil))
        let script = #"read event; case "$event" in *refresh*) printf '{"text":'; sleep 0.02; printf '"received"}\n';; esac"#
        try await PluginProcess.run(configuration: .init(executable: "/bin/sh", arguments: ["-c", script], restart: false), mailbox: mailbox) { value in
            messages.withLock { $0.append(value) }
        }
        #expect(messages.withLock { $0 } == ["received"])
    }

    @Test("Malformed plugin output fails in isolation")
    func malformed() async {
        await #expect(throws: (any Error).self) {
            try await PluginProcess.run(configuration: .init(executable: "/bin/sh", arguments: ["-c", "printf 'not-json\\n'"], restart: false), mailbox: PluginMailbox()) { _ in }
        }
    }

    @Test("Plugin cancellation stops a quiet process")
    func cancel() async throws {
        let task = Task {
            try await PluginProcess.run(configuration: .init(executable: "/bin/sh", arguments: ["-c", "sleep 10"], restart: false), mailbox: PluginMailbox()) { _ in }
        }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await #expect(throws: (any Error).self) { try await task.value }
    }

    @Test("Yabai uses labels and falls back to the space index")
    func workspace() throws {
        #expect(try WorkspaceAdapter.yabaiLabel(Data(#"{"index":2,"label":"work"}"#.utf8)) == "work")
        #expect(try WorkspaceAdapter.yabaiLabel(Data(#"{"index":2,"label":""}"#.utf8)) == "2")
    }
}
