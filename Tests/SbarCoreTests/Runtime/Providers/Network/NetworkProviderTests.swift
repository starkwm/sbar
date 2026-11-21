import Testing

@testable import SbarCore

@Suite("NetworkProvider")
@MainActor
struct NetworkProviderTests {
  @Test("stop: drops updates queued before the provider stopped")
  func queuedUpdateAfterStop() async throws {
    let monitors = TestNetworkPathMonitors()
    let provider = NetworkProvider(makeMonitor: monitors.make)
    var states: [WidgetState] = []
    provider.start { states.append($0) }

    monitors.emit(.wifi, from: 0)
    provider.stop()
    // Main-actor jobs run in order, so the queued update has run once this one finishes.
    await Task { @MainActor in }.value

    #expect(states.isEmpty)
    #expect(monitors.cancelled == [true])
  }

  @Test("start: a restart drops updates queued by the previous activation")
  func queuedUpdateAfterRestart() async throws {
    let monitors = TestNetworkPathMonitors()
    let provider = NetworkProvider(makeMonitor: monitors.make)
    defer { provider.stop() }
    var previous: [WidgetState] = []
    var current: [WidgetState] = []
    provider.start { previous.append($0) }

    monitors.emit(.offline, from: 0)
    provider.start { current.append($0) }
    monitors.emit(.ethernet, from: 1)
    try await waitUntil { !current.isEmpty }

    #expect(previous.isEmpty)
    #expect(current == [.network(.ethernet)])
  }
}

@MainActor
private final class TestNetworkPathMonitors {
  private var monitors: [TestNetworkPathMonitor] = []

  var cancelled: [Bool] { monitors.map(\.cancelled) }

  func make() -> any NetworkPathMonitoring {
    let monitor = TestNetworkPathMonitor()
    monitors.append(monitor)

    return monitor
  }

  /// Calls a monitor's handler even after cancellation, as a queued NWPathMonitor callback can.
  func emit(_ connection: NetworkConnection, from index: Int) {
    monitors[index].changed?(connection)
  }
}

@MainActor
private final class TestNetworkPathMonitor: NetworkPathMonitoring {
  var changed: (@Sendable (NetworkConnection) -> Void)?
  var cancelled = false

  func start(changed: @escaping @Sendable (NetworkConnection) -> Void) { self.changed = changed }
  func cancel() { cancelled = true }
}
