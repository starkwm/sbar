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
}
