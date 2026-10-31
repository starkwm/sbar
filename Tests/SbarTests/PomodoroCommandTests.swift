import ArgumentParser
import Testing

@testable import Sbar

@Suite("PomodoroCommand")
struct PomodoroCommandTests {
  @Test(
    "parseAsRoot: accepts timer operations and socket overrides",
    arguments: ["status", "start", "pause", "resume", "toggle", "reset", "skip"]
  )
  func operations(operation: String) throws {
    let command = try #require(
      SbarCommand.parseAsRoot(["pomodoro", operation, "--socket", "/tmp/pomodoro.sock"])
        as? PomodoroCommand
    )
    #expect(command.operation.rawValue == operation)
    #expect(command.options.socket == "/tmp/pomodoro.sock")
  }

  @Test("parseAsRoot: rejects missing and unsupported operations")
  func invalidArguments() {
    for args in [["pomodoro"], ["pomodoro", "stop"], ["pomodoro", "start", "extra"]] {
      #expect(throws: (any Error).self) { try SbarCommand.parseAsRoot(args) }
    }
  }
}
