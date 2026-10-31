import AppKit

@MainActor
final class PomodoroProvider: NSObject {
  private(set) var soundError: String?
  var state: PomodoroState? { session?.state }

  private let now: () -> Double
  private let sleep: @MainActor () async throws -> Void
  private let playSound: () -> Bool
  private let notifications: NotificationCenter
  private var session: PomodoroSession?
  private var update: ((PomodoroState) -> Void)?
  private var task: Task<Void, Never>?
  private var generation = 0
  private var sleeping = false

  init(
    now: (() -> Double)? = nil,
    sleep: @escaping @MainActor () async throws -> Void = {
      try await Task.sleep(for: .seconds(1))
    },
    playSound: @escaping () -> Bool = { NSSound(named: "Glass")?.play() ?? false },
    notifications: NotificationCenter = NSWorkspace.shared.notificationCenter
  ) {
    let clock = ContinuousClock()
    let origin = clock.now
    self.now =
      now ?? {
        let elapsed = origin.duration(to: clock.now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
      }
    self.sleep = sleep
    self.playSound = playSound
    self.notifications = notifications
    super.init()
  }

  func configure(_ settings: PomodoroSettings, update: @escaping (PomodoroState) -> Void) {
    if session == nil {
      session = PomodoroSession(settings: settings)
      notifications.addObserver(
        self,
        selector: #selector(willSleep),
        name: NSWorkspace.willSleepNotification,
        object: nil
      )
      notifications.addObserver(
        self,
        selector: #selector(didWake),
        name: NSWorkspace.didWakeNotification,
        object: nil
      )
    } else {
      session?.configure(settings)
    }
    self.update = update
    reconcile()
    publish()
    schedule()
  }

  @discardableResult
  func perform(_ operation: PomodoroOperation) throws -> PomodoroState {
    guard session != nil else { throw MessageError.message("No active pomodoro item.") }
    reconcile()
    session?.perform(operation, now: now())
    publish()
    schedule()
    return session!.state
  }

  func stop() {
    generation += 1
    task?.cancel()
    task = nil
    notifications.removeObserver(self)
    session = nil
    update = nil
    sleeping = false
    soundError = nil
  }

  private func reconcile(afterSleep: Bool = false) {
    guard !sleeping else { return }
    if session?.reconcile(now: now(), afterSleep: afterSleep) == true,
      session?.state.configured.sound == true
    {
      soundError = playSound() ? nil : "Could not play pomodoro completion sound."
    }
  }

  private func publish() {
    if let state = session?.state { update?(state) }
  }

  private func schedule() {
    generation += 1
    task?.cancel()
    task = nil
    guard !sleeping, session?.state.status == .running else { return }
    let generation = generation
    let sleep = sleep
    task = Task { [weak self] in
      do { try await sleep() } catch { return }
      guard !Task.isCancelled, let self, self.generation == generation else { return }
      self.reconcile()
      self.publish()
      self.schedule()
    }
  }

  @objc private func willSleep(_ notification: Notification) {
    reconcile()
    sleeping = true
    publish()
    schedule()
  }

  @objc private func didWake(_ notification: Notification) {
    guard sleeping else { return }
    sleeping = false
    reconcile(afterSleep: true)
    publish()
    schedule()
  }
}
