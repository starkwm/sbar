import Foundation
import StarkIPC
import Testing

@testable import SbarCore

@Suite("ControlServer and ControlRouter")
struct ControlTests {
  @Test(
    "ControlServer.start: only successful stop replies invoke the stop callback",
    arguments: [false, true]
  )
  func stopCallback(ok: Bool) throws {
    let path = "/tmp/sbar-\(UUID().uuidString).sock"
    defer { try? FileManager.default.removeItem(atPath: path + ".lock") }
    let stopped = DispatchSemaphore(value: 0)
    let server = ControlServer(
      path: path,
      onStop: { stopped.signal() },
      handler: { _ in ControlResponse(ok: ok) }
    )
    try server.start()
    defer { server.stop() }
    let client = try SocketClient(path: path, serviceName: "sbar")
    try client.send(ControlRequest(command: "stop"))

    #expect(try client.receive(ControlResponse.self).ok == ok)

    // Synchronise with the server queue so a failed reply cannot call onStop later.
    server.stop()

    #expect(stopped.wait(timeout: .now()) == (ok ? .success : .timedOut))
  }

  @Test("ControlServer.publish: subscriptions receive published events")
  func subscriptionReceivesEvents() throws {
    let path = "/tmp/sbar-\(UUID().uuidString).sock"
    defer { try? FileManager.default.removeItem(atPath: path + ".lock") }
    let server = ControlServer(path: path) { _ in ControlResponse() }
    try server.start()
    defer { server.stop() }
    let client = try SocketClient(path: path, serviceName: "sbar")
    try client.send(ControlRequest(command: "subscribe"))

    #expect(try client.receive(ControlResponse.self).ok)

    server.publish(ControlResponse(value: .string("changed")))

    #expect(try client.receive(ControlResponse.self).value == .string("changed"))
  }

  @MainActor
  @Test("ControlRouter.handle: retains file errors in diagnostics after runtime edits")
  func diagnostics() throws {
    let url = FileManager.default.temporaryDirectory.appending(
      path: "sbar-\(UUID().uuidString).json"
    )
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("{".utf8).write(to: url)
    let store = ConfigurationStore(configurationURL: url)
    store.load()

    let actions = ActionRunner()
    actions.run(ItemAction(kind: .url, value: "invalid"))

    let events = EventBus()
    events.emit(RuntimeEvent(kind: .trigger, name: "check", value: .number(1)))

    let router = ControlRouter(
      store: store,
      providers: ProviderRuntime(),
      events: events,
      actions: actions
    )

    #expect(
      router.handle(
        ControlRequest(command: "set", arguments: ["clock", "enabled"], value: .bool(false))
      ).ok
    )

    let error = try #require(store.errorMessage)
    let response = router.handle(ControlRequest(command: "query", arguments: ["diagnostics"]))
    guard case .object(let values) = response.value else {
      Issue.record("Missing diagnostics")

      return
    }

    #expect(values["configurationError"] == .string(error))
    #expect(values["actionError"] == .string("Invalid URL action."))
    #expect(values["configurationPath"] == .string(url.path))

    guard case .array(let recent) = values["events"] else {
      Issue.record("Missing events")

      return
    }

    #expect(recent.count == 1)

    #expect(!router.handle(ControlRequest(command: "query", arguments: ["unknown"])).ok)
    #expect(router.handle(ControlRequest(command: "stop")).ok)
  }

  @MainActor
  @Test("ControlRouter.handle: validates transient edits and retains trigger payloads")
  func runtimeEdits() {
    let store = ConfigurationStore(
      configurationURL: URL(fileURLWithPath: "/tmp/not-created-\(UUID().uuidString).json")
    )
    let events = EventBus()
    let router = ControlRouter(
      store: store,
      providers: ProviderRuntime(),
      events: events,
      actions: ActionRunner()
    )

    #expect(
      router.handle(
        ControlRequest(command: "set", arguments: ["clock", "enabled"], value: .bool(false))
      ).ok
    )
    #expect(store.configuration.items.right.last?.enabled == false)

    #expect(
      !router.handle(
        ControlRequest(command: "set", arguments: ["clock", "priority"], value: .string("bad"))
      ).ok
    )
    #expect(!FileManager.default.fileExists(atPath: store.configurationURL.path))

    #expect(
      router.handle(ControlRequest(command: "trigger", arguments: ["refresh"], value: .number(3)))
        .ok
    )
    #expect(events.recent.last?.value == .number(3))
  }

}
