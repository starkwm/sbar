import Darwin
import Foundation
import Testing

@testable import SbarCore

struct ControlTests {
  @Test("Control socket handles a fragmented request and excludes a second server")
  func socket() throws {
    let path = "/tmp/starkbar-\(UUID().uuidString).sock"
    defer { try? FileManager.default.removeItem(atPath: path + ".lock") }
    let server = ControlServer(path: path) { request in
      ControlResponse(value: .string(request.command))
    }
    try server.start()
    defer { server.stop() }
    let other = ControlServer(path: path) { _ in ControlResponse() }
    #expect(throws: (any Error).self) { try other.start() }
    let fd = try LocalSocket.connect(path: path)
    defer { close(fd) }
    var timeout = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    let data = try JSONEncoder().encode(ControlRequest(command: "query"))
    try LocalSocket.send(data.prefix(5), to: fd)
    try LocalSocket.send(data.dropFirst(5) + Data([10]), to: fd)
    var buffer = [UInt8](repeating: 0, count: 1024)
    let count = recv(fd, &buffer, buffer.count, 0)
    #expect(count > 0)
    let response = try JSONDecoder().decode(
      ControlResponse.self,
      from: Data(buffer.prefix(max(0, count)))
    )
    #expect(response.ok)
    #expect(response.value == .string("query"))
  }

  @MainActor @Test("Diagnostics retain file errors across runtime edits")
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

  @MainActor @Test("Runtime set validates without persisting and trigger retains payload")
  func routing() {
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
