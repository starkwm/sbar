import Foundation

struct PomodoroState: Equatable, Sendable {
  var phase: PomodoroPhase = .focus
  var status: PomodoroStatus = .ready
  var remaining: Double = 1500
  var completedSessions = 0
  var activeTiming = PomodoroTiming()
  var configured = PomodoroSettings()

  var duration: Double { activeTiming.seconds(for: phase) }
  var remainingSeconds: Int { Int(ceil(max(0, remaining))) }
  var countdown: String {
    String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
  }
  var progress: Int { min(100, max(0, Int((1 - remaining / duration) * 100))) }
  var text: String {
    "\(phase.label) \(countdown)" + (status == .running ? "" : " · \(status.rawValue.capitalized)")
  }
  var textValues: [String: String] {
    [
      "value": text, "phase": phase.rawValue, "phaseLabel": phase.label, "status": status.rawValue,
      "remaining": countdown, "remainingSeconds": String(remainingSeconds),
      "durationSeconds": String(Int(duration)), "progress": String(progress),
      "completedSessions": String(completedSessions),
      "cyclesBeforeLongBreak": String(activeTiming.cyclesBeforeLongBreak),
    ]
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.pomodoro ?? PomodoroConfiguration()
    let symbol =
      settings.symbols?.resolve(phase: phase, status: status)
      ?? (status == .paused ? "pause.circle" : phase.symbol)
    let tint =
      (status == .paused ? settings.tints?["paused"] : nil) ?? settings.tints?[phase.rawValue]
    return WidgetPresentation(
      text: text,
      symbol: settings.showSymbol == false ? nil : item.symbol ?? symbol,
      tint: tint,
      accessibilityLabel:
        "Pomodoro, \(phase.label), \(status.rawValue), \(remainingSeconds / 60) minutes \(remainingSeconds % 60) seconds remaining, \(completedSessions) of \(activeTiming.cyclesBeforeLongBreak) focus sessions completed"
    )
  }

  func jsonValue() throws -> JSONValue {
    func timing(_ value: PomodoroTiming) throws -> JSONValue {
      try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }
    return .object([
      "phase": .string(phase.rawValue), "status": .string(status.rawValue),
      "remainingSeconds": .number(Double(remainingSeconds)), "durationSeconds": .number(duration),
      "progress": .number(Double(progress)),
      "completedSessions": .number(Double(completedSessions)),
      "activeTiming": try timing(activeTiming), "configuredTiming": try timing(configured.timing),
      "resetRequired": .bool(activeTiming != configured.timing),
      "autoStart": .bool(configured.autoStart), "sound": .bool(configured.sound),
    ])
  }
}

enum PomodoroPhase: String, Codable, CaseIterable, Sendable {
  case focus, shortBreak, longBreak

  var label: String {
    switch self {
    case .focus: "Focus"
    case .shortBreak: "Short break"
    case .longBreak: "Long break"
    }
  }

  var symbol: ItemSymbol {
    switch self {
    case .focus: "timer"
    case .shortBreak: "cup.and.saucer"
    case .longBreak: "moon.zzz"
    }
  }
}

enum PomodoroStatus: String, Codable, CaseIterable, Sendable { case ready, running, paused }
enum PomodoroOperation: String, CaseIterable, Sendable {
  case status, start, pause, resume, toggle, reset, skip
}
