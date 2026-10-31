struct PomodoroTiming: Codable, Equatable, Sendable {
  var focusMinutes = 25
  var shortBreakMinutes = 5
  var longBreakMinutes = 15
  var cyclesBeforeLongBreak = 4

  func seconds(for phase: PomodoroPhase) -> Double {
    let minutes =
      switch phase {
      case .focus: focusMinutes
      case .shortBreak: shortBreakMinutes
      case .longBreak: longBreakMinutes
      }
    return Double(minutes) * 60
  }
}

struct PomodoroSettings: Equatable, Sendable {
  var timing = PomodoroTiming()
  var autoStart = false
  var sound = false
}
