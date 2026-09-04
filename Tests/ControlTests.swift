import ControlProtocol
import Darwin
import Foundation
import Testing

@testable import sbar

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

  @MainActor @Test("Runtime set validates without persisting and trigger retains payload")
  func routing() {
    let store = ConfigurationStore(
      configurationURL: URL(fileURLWithPath: "/tmp/not-created-\(UUID().uuidString).json")
    )
    let events = EventBus()
    let router = ControlRouter(store: store, providers: ProviderRegistry(), events: events)
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
