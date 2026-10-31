import ArgumentParser
import SbarCore

struct PomodoroCommand: ParsableCommand {
  enum Operation: String, ExpressibleByArgument, CaseIterable {
    case status, start, pause, resume, toggle, reset, skip
  }

  static let configuration = CommandConfiguration(
    commandName: "pomodoro",
    abstract: "Inspect or control the shared pomodoro timer."
  )

  @OptionGroup var options: SocketOptions
  @Argument(help: "Operation: status, start, pause, resume, toggle, reset, or skip.")
  var operation: Operation

  mutating func run() throws {
    try options.send(ControlRequest(command: "pomodoro", arguments: [operation.rawValue]))
  }
}
