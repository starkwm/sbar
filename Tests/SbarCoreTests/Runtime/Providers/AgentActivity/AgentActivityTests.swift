import Foundation
import Testing

@testable import SbarCore

@Suite("AgentActivityStore")
@MainActor
struct AgentActivityTests {
  @Test("report: simultaneous sessions, retained metadata and duplicate delivery")
  func simultaneous() throws {
    let store = AgentActivityStore()
    try store.report(
      AgentActivityReport(
        source: "custom",
        session: "a",
        run: "1",
        sequence: 0,
        state: .working,
        title: "Build"
      )
    )
    try store.report(
      AgentActivityReport(source: "custom", session: "b", run: "1", sequence: 0, state: .needsInput)
    )
    let next = AgentActivityReport(
      source: "custom",
      session: "a",
      run: "1",
      sequence: 1,
      state: .finished
    )
    try store.report(next)
    try store.report(next)

    #expect(store.snapshot().entries.count == 2)
    #expect(store.entries["custom:a"]?.report.title == "Build")
    #expect(store.snapshot().status == .needsInput)
  }

  @Test("snapshot: working outranks lingering unknown and idle sessions")
  func attention() throws {
    let store = AgentActivityStore()
    for (session, state) in [("a", AgentActivityStatus.idle), ("b", .finished)] {
      try store.report(
        AgentActivityReport(source: "custom", session: session, run: "1", sequence: 0, state: state)
      )
    }
    #expect(store.snapshot().status == .idle)

    try store.report(
      AgentActivityReport(source: "custom", session: "c", run: "1", sequence: 0, state: .unknown)
    )
    try store.report(
      AgentActivityReport(source: "custom", session: "d", run: "1", sequence: 0, state: .working)
    )
    #expect(store.snapshot().status == .working)
  }

  @Test("report: transitions compare the predecessor and reject delayed completion")
  func ordering() throws {
    let store = AgentActivityStore()
    try store.report(
      AgentActivityReport(source: "custom", session: "a", run: "z", sequence: 3, state: .working)
    )
    #expect(throws: (any Error).self) {
      try store.report(
        AgentActivityReport(source: "custom", session: "a", run: "z", sequence: 2, state: .finished)
      )
    }
    #expect(throws: (any Error).self) {
      try store.report(
        AgentActivityReport(source: "custom", session: "a", run: "a", sequence: 0, state: .working)
      )
    }
    try store.report(
      AgentActivityReport(
        source: "custom",
        session: "a",
        run: "a",
        sequence: 0,
        state: .working,
        replaces: "z"
      )
    )
    #expect(throws: (any Error).self) {
      try store.report(
        AgentActivityReport(
          source: "custom",
          session: "a",
          run: "z",
          sequence: 4,
          state: .finished,
          replaces: "a"
        )
      )
    }
    #expect(store.entries["custom:a"]?.report.run == "a")
  }

  @Test("snapshot: heartbeat expiry is unknown while event-only silence preserves state")
  func expiry() throws {
    let store = AgentActivityStore()
    let now = Date(timeIntervalSince1970: 100)
    try store.report(
      AgentActivityReport(
        source: "custom",
        session: "a",
        run: "1",
        sequence: 0,
        state: .working,
        heartbeatSeconds: 10
      ),
      now: now
    )
    try store.report(
      AgentActivityReport(
        source: "custom",
        session: "b",
        run: "1",
        sequence: 0,
        state: .needsInput
      ),
      now: now
    )
    let entries = store.snapshot(now: now.addingTimeInterval(11)).entries
    #expect(entries.map(\.state) == [.unknown, .needsInput])
  }

  @Test("snapshot: only explicit host identity suppresses a standalone session")
  func correlation() throws {
    let store = AgentActivityStore()
    try store.report(
      AgentActivityReport(
        source: "codex",
        session: "a",
        run: "1",
        sequence: 0,
        state: .working,
        title: "Same",
        identity: "codex:a"
      )
    )
    try store.report(
      AgentActivityReport(
        source: "custom-host",
        session: "b",
        run: "1",
        sequence: 0,
        state: .working,
        title: "Same",
        host: "custom-host",
        agent: "codex"
      )
    )
    #expect(store.snapshot().entries.count == 2)
    try store.report(
      AgentActivityReport(
        source: "custom-host",
        session: "b",
        run: "1",
        sequence: 1,
        state: .working,
        host: "custom-host",
        agent: "codex",
        identity: "codex:a"
      )
    )
    #expect(store.snapshot().entries.map(\.report.source) == ["custom-host"])
  }

  @Test("selected: retention, filters and dismissal survive heartbeats")
  func retention() throws {
    let store = AgentActivityStore()
    let now = Date(timeIntervalSince1970: 100)
    try store.report(
      AgentActivityReport(
        source: "pi",
        session: "a",
        run: "1",
        sequence: 0,
        state: .finished,
        project: "one"
      ),
      now: now
    )
    try store.report(
      AgentActivityReport(source: "pi", session: "a", run: "1", sequence: 1, state: .finished),
      now: now.addingTimeInterval(29)
    )
    #expect(
      store.snapshot(now: now.addingTimeInterval(31)).selected(AgentActivityConfiguration()).entries
        .isEmpty
    )
    #expect(
      store.snapshot(now: now).selected(AgentActivityConfiguration(projects: ["two"])).entries
        .isEmpty
    )
    store.dismiss(source: "pi", session: "a")
    try store.report(
      AgentActivityReport(source: "pi", session: "a", run: "1", sequence: 2, state: .finished)
    )
    #expect(store.snapshot().entries.isEmpty)
    try store.report(
      AgentActivityReport(
        source: "pi",
        session: "a",
        run: "2",
        sequence: 0,
        state: .working,
        replaces: "1"
      )
    )
    #expect(store.snapshot().entries.count == 1)
    store.clear()
    #expect(store.entries.isEmpty)
  }
  @Test("configure: reload preserves sessions and removal or shutdown clears shared state")
  func lifecycle() async throws {
    let runtime = ProviderRuntime()
    defer { runtime.stop() }
    let item = Item(
      id: "agents",
      type: .agentActivity,
      text: "{{working}}/{{total}} {{#sessions}}{{title}}{{/sessions}}"
    )
    let configuration = Configuration(bar: .init(), items: .init(right: [item]))
    try configuration.validate()
    runtime.configure(configuration)
    try runtime.agents.report(
      AgentActivityReport(
        source: "custom",
        session: "a",
        run: "1",
        sequence: 0,
        state: .working,
        title: "Build"
      )
    )
    runtime.publishAgents()
    #expect(runtime.presentation(for: item)?.text == "1/1 Build")
    runtime.configure(configuration)
    #expect(runtime.agents.entries.count == 1)
    runtime.configure(Configuration(bar: .init(), items: .init()))
    #expect(runtime.agents.entries.isEmpty)
    #expect(runtime.widgetStates[.agentActivity] == nil)
    runtime.configure(configuration)
    #expect(runtime.presentation(for: item)?.hidden == true)
    runtime.stop()
    try await Task.sleep(for: .milliseconds(20))
    #expect(runtime.widgetStates.isEmpty)
  }

  @Test("handle: reports are validated and acknowledged independently of triggers")
  func socketRouting() throws {
    let runtime = ProviderRuntime()
    defer { runtime.stop() }
    runtime.configure(
      Configuration(bar: .init(), items: .init(right: [Item(id: "agents", type: .agentActivity)]))
    )
    let router = ControlRouter(
      store: ConfigurationStore(),
      providers: runtime,
      events: EventBus(),
      actions: ActionRunner()
    )
    let value = try JSONDecoder().decode(
      JSONValue.self,
      from: Data(
        #"{"version":1,"source":"custom","session":"a","run":"1","sequence":0,"state":"working"}"#
          .utf8
      )
    )
    #expect(
      router.handle(ControlRequest(command: "agents", arguments: ["report"], value: value)).ok
    )
    #expect(
      router.handle(ControlRequest(command: "agents", arguments: ["report"], value: value)).ok
    )
    #expect(
      !router.handle(
        ControlRequest(command: "agents", arguments: ["report"], value: .string("invalid"))
      ).ok
    )
    #expect(runtime.agents.entries.count == 1)
    #expect(
      router.handle(ControlRequest(command: "agents", arguments: ["dismiss", "custom", "a"])).ok
    )
    #expect(runtime.agents.snapshot().entries.isEmpty)
  }
}
