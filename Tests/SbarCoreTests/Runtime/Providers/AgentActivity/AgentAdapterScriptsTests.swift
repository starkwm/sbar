import Foundation
import Testing

@testable import SbarCore

@Suite("AgentAdapterScripts")
struct AgentAdapterScriptsTests {
  @Test(
    "setup and doctor: reject unsupported sources before touching configuration",
    arguments: ["setup", "doctor"]
  )
  func unsupportedSource(action: String) throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let script = root.appending(path: "adapter.sh")
    try AgentAdapterScripts.adapter.write(to: script, atomically: true, encoding: .utf8)
    let settings = root.appending(path: "settings.json")
    let original = Data(#"{"hooks":{},"unrelated":"preserve"}"#.utf8)
    try original.write(to: settings)
    let before = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
    let output = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script.path, action, "--source", "t3", "--root", root.path]
    process.standardOutput = output
    process.standardError = output

    try process.run()
    process.waitUntilExit()
    let diagnostic = String(
      decoding: output.fileHandleForReading.readDataToEndOfFile(),
      as: UTF8.self
    )

    #expect(process.terminationStatus != 0)
    #expect(diagnostic.contains("Expected --source codex, claude or pi."))
    #expect(try Data(contentsOf: settings) == original)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == before)
  }

  @Test("hook: a hook killed after sbar accepts its report does not block later states")
  @MainActor
  func interruptedCachePersistence() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let script = root.appending(path: "adapter.sh")
    try AgentAdapterScripts.adapter.write(to: script, atomically: true, encoding: .utf8)
    // Stands in for the daemon: lists the last report, logs each report, and on request
    // kills the adapter after acknowledging, before it can persist its cache.
    let sbar = root.appending(path: "sbar")
    try #"""
    #!/bin/bash
    dir=$(dirname "$0")
    case $2 in
    list) jq -c '{value: [{report: .}]}' "$dir/current.json" 2>/dev/null || echo '{"value":[]}' ;;
    report)
      tee "$dir/current.json" >>"$dir/reports.jsonl"
      if [[ -f $dir/kill ]]; then rm "$dir/kill" && kill -9 $PPID; fi
      ;;
    esac
    """#.write(to: sbar, atomically: true, encoding: .utf8)
    for executable in [script, sbar] {
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: executable.path
      )
    }

    func hook(_ event: String) throws {
      let process = Process()
      let input = Pipe()
      process.executableURL = URL(fileURLWithPath: "/bin/bash")
      process.arguments = [
        script.path, "hook", "--source", "claude", "--socket", root.appending(path: "sock").path,
        "--cache", root.appending(path: "cache").path, "--sbar", sbar.path,
      ]
      process.standardInput = input
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      try process.run()
      input.fileHandleForWriting.write(
        Data(#"{"hook_event_name":"\#(event)","session_id":"s","prompt_id":"p"}"#.utf8)
      )
      try input.fileHandleForWriting.close()
      process.waitUntilExit()
    }

    try hook("UserPromptSubmit")
    FileManager.default.createFile(atPath: root.appending(path: "kill").path, contents: nil)
    try hook("PermissionRequest")
    try hook("Stop")

    let reports = try String(contentsOf: root.appending(path: "reports.jsonl"), encoding: .utf8)
      .split(separator: "\n")
      .map { try JSONDecoder().decode(AgentActivityReport.self, from: Data($0.utf8)) }

    #expect(reports.map(\.sequence) == [0, 1, 2])
    #expect(reports.map(\.state) == [.working, .needsInput, .idle])

    let store = AgentActivityStore()
    for report in reports { try store.report(report) }

    #expect(store.entries["claude:s"]?.state == .idle)
    #expect(throws: (any Error).self) { try store.report(reports[1]) }
  }
}
