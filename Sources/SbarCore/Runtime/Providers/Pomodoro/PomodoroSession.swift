struct PomodoroSession {
  private(set) var state: PomodoroState
  private var deadline: Double?

  init(settings: PomodoroSettings) {
    state = PomodoroState(
      remaining: settings.timing.seconds(for: .focus),
      activeTiming: settings.timing,
      configured: settings
    )
  }

  mutating func configure(_ settings: PomodoroSettings) { state.configured = settings }

  @discardableResult
  mutating func reconcile(now: Double, afterSleep: Bool = false) -> Bool {
    guard let deadline, state.status == .running else { return false }
    state.remaining = max(0, deadline - now)
    guard now >= deadline else { return false }
    advance(completed: true)
    if state.configured.autoStart && !afterSleep { start(now: now) }
    return true
  }

  mutating func perform(_ operation: PomodoroOperation, now: Double) {
    switch operation {
    case .status: break
    case .start:
      if state.status == .ready { start(now: now) }
    case .resume:
      if state.status == .paused { start(now: now) }
    case .pause:
      if state.status == .running {
        state.status = .paused
        deadline = nil
      }
    case .toggle:
      if state.status == .running { perform(.pause, now: now) } else { start(now: now) }
    case .reset:
      self = Self(settings: state.configured)
    case .skip:
      advance(completed: false)
    }
  }

  private mutating func start(now: Double) {
    state.status = .running
    deadline = now + state.remaining
  }

  private mutating func advance(completed: Bool) {
    switch state.phase {
    case .focus:
      if completed { state.completedSessions += 1 }
      state.phase =
        state.completedSessions >= state.activeTiming.cyclesBeforeLongBreak
        ? .longBreak : .shortBreak
    case .shortBreak:
      state.phase = .focus
    case .longBreak:
      state.completedSessions = 0
      state.phase = .focus
    }
    state.status = .ready
    state.remaining = state.duration
    deadline = nil
  }
}
