import Foundation

struct ItemAction: Codable, Equatable, Sendable {
  enum Kind: String, Codable, CaseIterable, Sendable { case command, url, application, pomodoro }

  var kind: Kind
  var value: String

  func validate(path: String) throws {
    if kind == .pomodoro, PomodoroOperation(rawValue: value) == nil || value == "status" {
      throw ConfigurationError.invalidValue(
        path: "\(path).value",
        reason: "Expected start, pause, resume, toggle, reset, or skip."
      )
    }
  }
}
