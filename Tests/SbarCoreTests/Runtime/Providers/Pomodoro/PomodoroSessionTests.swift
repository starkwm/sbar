import Testing

@testable import SbarCore

@Suite("PomodoroSession")
struct PomodoroSessionTests {
  @Test(
    "reconcile: completed focus sessions select long breaks and restart the cycle",
    arguments: [1, 4]
  )
  func cycles(count: Int) {
    var session = PomodoroSession(settings: .init(timing: .init(cyclesBeforeLongBreak: count)))
    var now = 0.0

    for index in 1...count {
      session.perform(.start, now: now)
      now += 1500
      let completed1 = session.reconcile(now: now)
      #expect(completed1)
      #expect(session.state.completedSessions == index)
      #expect(session.state.phase == (index == count ? .longBreak : .shortBreak))
      #expect(session.state.status == .ready)
      let completed2 = session.reconcile(now: now)
      #expect(!completed2)

      session.perform(.start, now: now)
      now += index == count ? 900 : 300
      let completed3 = session.reconcile(now: now)
      #expect(completed3)
      #expect(session.state.phase == .focus)
    }
    #expect(session.state.completedSessions == 0)
  }

  @Test("reconcile: delayed expiry starts one full successor and sleep overrides automatic mode")
  func automaticAndSleep() {
    var session = PomodoroSession(settings: .init(autoStart: true))
    session.perform(.start, now: 0)

    let completed4 = session.reconcile(now: 1499.1)

    #expect(!completed4)
    #expect(session.state.remainingSeconds == 1)
    let completed5 = session.reconcile(now: 100_000)
    #expect(completed5)
    #expect(session.state.phase == .shortBreak)
    #expect(session.state.remaining == 300)
    #expect(session.state.completedSessions == 1)
    #expect(session.state.status == .running)

    let completed6 = session.reconcile(now: 200_000, afterSleep: true)

    #expect(completed6)
    #expect(session.state.phase == .focus)
    #expect(session.state.status == .ready)
    #expect(session.state.completedSessions == 1)
  }

  @Test("perform: pause preserves precise remainder and repeated controls do not restart")
  func controls() {
    var session = PomodoroSession(settings: .init())
    session.perform(.resume, now: 0)
    #expect(session.state.status == .ready)
    session.perform(.toggle, now: 0)
    session.perform(.start, now: 10)
    session.reconcile(now: 60.25)
    session.perform(.pause, now: 60.25)
    session.perform(.pause, now: 100)
    session.reconcile(now: 1000)
    #expect(session.state.remaining == 1439.75)

    session.perform(.resume, now: 1000)
    session.perform(.resume, now: 1100)
    let completed7 = session.reconcile(now: 2439.75)
    #expect(completed7)
    #expect(session.state.phase == .shortBreak)
  }

  @Test("perform: skip never credits focus and reset applies pending timing")
  func skipAndReset() {
    var session = PomodoroSession(settings: .init(timing: .init(cyclesBeforeLongBreak: 1)))
    session.perform(.skip, now: 0)
    #expect(session.state.phase == .shortBreak)
    #expect(session.state.completedSessions == 0)
    session.perform(.skip, now: 0)
    session.perform(.start, now: 0)
    session.reconcile(now: 1500)
    #expect(session.state.phase == .longBreak)
    session.perform(.skip, now: 1500)
    #expect(session.state.completedSessions == 0)

    session.perform(.start, now: 1500)
    session.configure(.init(timing: .init(focusMinutes: 10), autoStart: true))
    session.reconcile(now: 1510)
    #expect(session.state.remaining == 1490)
    #expect(session.state.activeTiming.focusMinutes == 25)
    session.perform(.reset, now: 1510)
    #expect(session.state.phase == .focus)
    #expect(session.state.status == .ready)
    #expect(session.state.remaining == 600)
    #expect(session.state.activeTiming == session.state.configured.timing)
  }
}
