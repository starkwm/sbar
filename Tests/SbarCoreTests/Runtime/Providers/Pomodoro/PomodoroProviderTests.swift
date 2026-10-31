import AppKit
import Testing

@testable import SbarCore

@Suite("PomodoroProvider")
@MainActor
struct PomodoroProviderTests {
  @Test("configure: reload preserves elapsed time and pending rules until reset")
  func reload() throws {
    var now = 0.0
    let provider = PomodoroProvider(now: { now }, notifications: NotificationCenter())
    var values: [PomodoroState] = []
    provider.configure(.init()) { values.append($0) }
    defer { provider.stop() }
    try provider.perform(.start)
    now = 30
    provider.configure(.init(timing: .init(focusMinutes: 10), autoStart: true)) {
      values.append($0)
    }

    #expect(provider.state?.remaining == 1470)
    #expect(provider.state?.configured.autoStart == true)
    #expect(provider.state?.activeTiming.focusMinutes == 25)
    let reset = try provider.perform(.reset)
    #expect(reset.remaining == 600)
    #expect(reset.status == .ready)
    #expect(values.last == reset)
  }

  @Test("perform: reconciles overdue controls once and reports sound failure")
  func expiry() throws {
    var now = 0.0
    var sounds = 0
    let provider = PomodoroProvider(
      now: { now },
      playSound: {
        sounds += 1
        return false
      },
      notifications: NotificationCenter()
    )
    provider.configure(.init(sound: true)) { _ in }
    defer { provider.stop() }
    try provider.perform(.start)
    now = 1600
    let state = try provider.perform(.pause)

    #expect(state.phase == .shortBreak)
    #expect(state.status == .ready)
    #expect(state.completedSessions == 1)
    #expect(sounds == 1)
    #expect(provider.soundError != nil)
    try provider.perform(.status)
    try provider.perform(.skip)
    try provider.perform(.reset)
    #expect(sounds == 1)
  }

  @Test(
    "sleep and wake: elapsed sleep counts but an expired successor waits for start",
    arguments: [false, true]
  )
  func sleepWake(autoStart: Bool) throws {
    var now = 0.0
    var sounds = 0
    let center = NotificationCenter()
    let provider = PomodoroProvider(
      now: { now },
      playSound: {
        sounds += 1
        return true
      },
      notifications: center
    )
    provider.configure(.init(autoStart: autoStart, sound: true)) { _ in }
    defer { provider.stop() }
    try provider.perform(.start)
    now = 100
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    now = 200
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(provider.state?.remaining == 1300)
    #expect(provider.state?.status == .running)

    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    now = 20_000
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(provider.state?.phase == .shortBreak)
    #expect(provider.state?.status == .ready)
    #expect(provider.state?.completedSessions == 1)
    #expect(sounds == 1)

    try provider.perform(.start)
    try provider.perform(.pause)
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    now += 1000
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(provider.state?.status == .paused)
    #expect(provider.state?.remaining == 300)
  }

  @Test("schedule: ticks publish countdown and completion without a control request")
  func scheduledExpiry() async throws {
    var now = 0.0
    var waits: [CheckedContinuation<Void, Never>] = []
    var values: [PomodoroState] = []
    let provider = PomodoroProvider(
      now: { now },
      sleep: { await withCheckedContinuation { waits.append($0) } },
      notifications: NotificationCenter()
    )
    defer {
      provider.stop()
      for continuation in waits { continuation.resume() }
    }
    provider.configure(.init()) { values.append($0) }
    try provider.perform(.start)
    try await waitUntil { waits.count == 1 }

    now = 1
    waits.removeFirst().resume()
    try await waitUntil { values.last?.remaining == 1499 && waits.count == 1 }

    now = 1500
    waits.removeFirst().resume()
    try await waitUntil { values.last?.phase == .shortBreak }
    #expect(values.last?.completedSessions == 1)
    #expect(values.last?.status == .ready)
    #expect(waits.isEmpty)
  }

  @Test("stop: cancelled scheduled callbacks cannot publish into a new activation")
  func staleCallbacks() async throws {
    var now = 0.0
    var waits: [CheckedContinuation<Void, Never>] = []
    let provider = PomodoroProvider(
      now: { now },
      sleep: {
        await withCheckedContinuation { waits.append($0) }
      },
      notifications: NotificationCenter()
    )
    var publications = 0
    provider.configure(.init()) { _ in publications += 1 }
    try provider.perform(.start)
    try await waitUntil { waits.count == 1 }
    #expect(waits.count == 1)
    provider.stop()
    provider.stop()
    #expect(throws: (any Error).self) { try provider.perform(.start) }
    provider.configure(.init()) { _ in publications += 1 }
    let previous = publications
    now = 5000
    for continuation in waits { continuation.resume() }
    for _ in 0..<10 { await Task.yield() }
    #expect(publications == previous)
    #expect(provider.state?.status == .ready)
    #expect(provider.state?.remaining == 1500)
    provider.stop()
  }
}
