import Foundation

struct PomodoroConfiguration: Codable, Equatable, Sendable {
  static let appearanceKeys: Set<String> = ["focus", "shortBreak", "longBreak", "paused"]

  static func resolve(_ items: [Item]) throws -> PomodoroSettings {
    let settings = items.filter { $0.type == .pomodoro }.map { ($0.id, $0.pomodoro ?? Self()) }

    func shared<T: Equatable>(_ key: KeyPath<Self, T?>, _ name: String, _ fallback: T) throws -> T {
      let supplied = settings.compactMap { id, value in value[keyPath: key].map { (id, $0) } }
      if let first = supplied.first,
        let conflict = supplied.first(where: { $0.1 != first.1 })
      {
        throw ConfigurationError.invalidValue(
          path: "pomodoro.\(name)",
          reason: "Conflicting values in items '\(first.0)' and '\(conflict.0)'."
        )
      }
      return supplied.first?.1 ?? fallback
    }

    return try PomodoroSettings(
      timing: PomodoroTiming(
        focusMinutes: shared(\.focusMinutes, "focusMinutes", 25),
        shortBreakMinutes: shared(\.shortBreakMinutes, "shortBreakMinutes", 5),
        longBreakMinutes: shared(\.longBreakMinutes, "longBreakMinutes", 15),
        cyclesBeforeLongBreak: shared(\.cyclesBeforeLongBreak, "cyclesBeforeLongBreak", 4)
      ),
      autoStart: shared(\.autoStart, "autoStart", false),
      sound: shared(\.sound, "sound", false)
    )
  }

  var focusMinutes: Int?
  var shortBreakMinutes: Int?
  var longBreakMinutes: Int?
  var cyclesBeforeLongBreak: Int?
  var autoStart: Bool?
  var sound: Bool?
  var symbols: PomodoroSymbols?
  var tints: [String: String]?
  var showSymbol: Bool?

  func validate(path: String) throws {
    for (name, value, range) in [
      ("focusMinutes", focusMinutes, 1...180),
      ("shortBreakMinutes", shortBreakMinutes, 1...180),
      ("longBreakMinutes", longBreakMinutes, 1...180),
      ("cyclesBeforeLongBreak", cyclesBeforeLongBreak, 1...12),
    ] {
      if let value, !range.contains(value) {
        throw ConfigurationError.invalidValue(
          path: "\(path).\(name)",
          reason: "Must be between \(range.lowerBound) and \(range.upperBound)."
        )
      }
    }
    try symbols?.validate(path: "\(path).symbols")
    for (key, color) in tints ?? [:] {
      guard Self.appearanceKeys.contains(key) else {
        throw ConfigurationError.invalidValue(
          path: "\(path).tints.\(key)",
          reason: "Unknown pomodoro tint."
        )
      }
      try ItemStyle.validateColor(color, path: "\(path).tints.\(key)")
    }
  }
}
