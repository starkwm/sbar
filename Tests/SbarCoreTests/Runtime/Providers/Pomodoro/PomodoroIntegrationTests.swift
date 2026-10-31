import Foundation
import Testing

@testable import SbarCore

@Suite("Pomodoro runtime controls")
@MainActor
struct PomodoroIntegrationTests {
  @Test("configure: popup mirrors share state while manual snapshots stay frozen")
  func runtime() throws {
    var now = 0.0
    let provider = PomodoroProvider(now: { now }, notifications: NotificationCenter())
    let runtime = ProviderRuntime(pomodoro: provider)
    defer { runtime.stop() }
    let live = Item(id: "live", type: .pomodoro, text: "{{remaining}} {{progress}}%")
    let frozen = Item(
      id: "frozen",
      type: .pomodoro,
      text: "{{remaining}} {{progress}}%",
      refresh: .init(mode: .manual)
    )
    let popup = Item(id: "popup", type: .popup, children: [frozen])
    var configuration = Configuration(bar: .init(), items: .init(right: [live, popup]))
    runtime.configure(configuration)
    try runtime.controlPomodoro(.start)
    now = 750
    try runtime.controlPomodoro(.status)

    #expect(runtime.presentation(for: live)?.text == "12:30 50%")
    #expect(runtime.presentation(for: live, displayUUID: "second")?.text == "12:30 50%")
    #expect(runtime.presentation(for: frozen)?.text == "25:00 0%")
    runtime.trigger("frozen")
    #expect(runtime.presentation(for: frozen)?.text == "12:30 50%")

    runtime.updateWidgetState(.cpu(CPUState(samples: [10])), for: .cpu)
    configuration.items.right[0].pomodoro = .init(focusMinutes: 10)
    runtime.configure(configuration)
    #expect(runtime.pomodoroState?.remaining == 750)
    #expect(runtime.widgetStates[.cpu] != nil)
    configuration.items.right = []
    runtime.configure(configuration)
    #expect(throws: (any Error).self) { try runtime.controlPomodoro(.status) }
    configuration.items.right = [live]
    runtime.configure(configuration)
    #expect(runtime.pomodoroState?.status == .ready)
    #expect(runtime.pomodoroState?.completedSessions == 0)
  }

  @Test("handle: CLI and native actions share state and reject unsupported requests")
  func routerAndActions() throws {
    let runtime = ProviderRuntime(pomodoro: PomodoroProvider(notifications: NotificationCenter()))
    defer { runtime.stop() }
    let actions = ActionRunner()
    actions.pomodoroAction = { try runtime.controlPomodoro($0) }
    let store = ConfigurationStore(
      configurationURL: URL(fileURLWithPath: "/tmp/not-created-\(UUID()).json")
    )
    let router = ControlRouter(
      store: store,
      providers: runtime,
      events: EventBus(),
      actions: actions
    )
    #expect(!router.handle(ControlRequest(command: "pomodoro", arguments: ["start"])).ok)
    runtime.configure(
      Configuration(bar: .init(), items: .init(right: [Item(id: "timer", type: .pomodoro)]))
    )
    let response = router.handle(ControlRequest(command: "pomodoro", arguments: ["start"]))
    #expect(response.ok)
    guard case .object(let value) = response.value else {
      Issue.record("Missing timer snapshot")
      return
    }
    #expect(value["status"] == .string("running"))
    #expect(value["resetRequired"] == .bool(false))
    actions.run(ItemAction(kind: .pomodoro, value: "pause"))
    #expect(runtime.pomodoroState?.status == .paused)
    #expect(actions.errorMessage == nil)
    actions.run(ItemAction(kind: .pomodoro, value: "invalid"))
    #expect(actions.errorMessage != nil)
    for arguments in [[], ["unknown"], ["start", "extra"]] {
      #expect(!router.handle(ControlRequest(command: "pomodoro", arguments: arguments)).ok)
    }
    #expect(
      !router.handle(ControlRequest(command: "pomodoro", arguments: ["start"], value: .bool(true)))
        .ok
    )
  }

  @Test("apply: invalid shared settings preserve the configured running timer")
  func invalidReload() throws {
    let runtime = ProviderRuntime(pomodoro: PomodoroProvider(notifications: NotificationCenter()))
    defer { runtime.stop() }
    let store = ConfigurationStore(
      configurationURL: URL(fileURLWithPath: "/tmp/not-created-\(UUID()).json")
    )
    store.configurationDidChange = { runtime.configure(store.configuration) }
    var candidate = Configuration(
      bar: .init(),
      items: .init(right: [Item(id: "timer", type: .pomodoro, pomodoro: .init(focusMinutes: 10))])
    )
    try store.apply(candidate)
    try runtime.controlPomodoro(.start)
    candidate.items.right.append(
      Item(id: "conflict", type: .pomodoro, pomodoro: .init(focusMinutes: 20))
    )
    #expect(throws: ConfigurationError.self) { try store.apply(candidate) }
    #expect(runtime.pomodoroState?.status == .running)
    #expect(runtime.pomodoroState?.activeTiming.focusMinutes == 10)
    #expect(store.configuration.items.right.count == 1)
  }
}
