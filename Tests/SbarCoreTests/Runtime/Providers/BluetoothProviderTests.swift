import CoreBluetooth
import Testing

@testable import SbarCore

@Suite("Bluetooth provider")
@MainActor
struct BluetoothProviderTests {
  @Test("native state mapping distinguishes power, denied access and pending initialization")
  func states() {
    #expect(SystemBluetoothMonitor.status(.unknown, authorization: .notDetermined) == nil)
    #expect(SystemBluetoothMonitor.status(.poweredOn, authorization: .notDetermined) == .on)
    #expect(SystemBluetoothMonitor.status(.poweredOff, authorization: .notDetermined) == .off)
    #expect(SystemBluetoothMonitor.status(.poweredOn, authorization: .allowedAlways) == .on)
    #expect(SystemBluetoothMonitor.status(.poweredOff, authorization: .allowedAlways) == .off)
    #expect(
      SystemBluetoothMonitor.status(.resetting, authorization: .allowedAlways) == .unavailable
    )
    #expect(
      SystemBluetoothMonitor.status(.unsupported, authorization: .allowedAlways) == .unavailable
    )
    #expect(
      SystemBluetoothMonitor.status(.unauthorized, authorization: .allowedAlways) == .unauthorized
    )
    for state in [CBManagerState.unknown, .poweredOn, .poweredOff] {
      for authorization in [CBManagerAuthorization.denied, .restricted] {
        #expect(SystemBluetoothMonitor.status(state, authorization: authorization) == .unauthorized)
      }
    }
  }

  @Test("pending initialization does not publish a false off or disconnected snapshot")
  func pending() async throws {
    let monitor = TestBluetoothMonitor()
    monitor.state = nil
    let provider = BluetoothProvider(monitor: monitor)
    defer { provider.stop() }
    var states: [BluetoothState] = []
    provider.start { states.append($0) }
    #expect(states.isEmpty)
    monitor.state = BluetoothState(status: .connected, devices: [.init(id: "1", name: "Keyboard")])
    monitor.changed?()
    try await Task.sleep(for: .milliseconds(150))
    #expect(states == [monitor.state])
  }

  @Test("failed startup recovers without needing a Bluetooth event")
  func recovery() async throws {
    let monitor = TestBluetoothMonitor()
    monitor.canStart = false
    let provider = BluetoothProvider(monitor: monitor)
    defer { provider.stop() }
    var states: [BluetoothState] = []
    provider.start { states.append($0) }
    #expect(states == [BluetoothState()])
    #expect(monitor.reads == 0)
    monitor.canStart = true
    try await Task.sleep(for: .milliseconds(2200))
    #expect(monitor.starts == 2)
    #expect(states.last == BluetoothState(status: .on))
  }

  @Test("events coalesce and callbacks from stopped or replaced sessions are ignored")
  func lifecycle() async throws {
    let monitor = TestBluetoothMonitor()
    let provider = BluetoothProvider(monitor: monitor)
    defer { provider.stop() }
    var oldUpdates = 0
    var states: [BluetoothState] = []
    provider.start { _ in oldUpdates += 1 }
    let stale = monitor.changed
    provider.start { states.append($0) }
    monitor.state = BluetoothState(status: .off)
    monitor.changed?()
    monitor.changed?()
    monitor.changed?()
    try await Task.sleep(for: .milliseconds(150))
    #expect(oldUpdates == 1)
    #expect(states.count == 2)
    #expect(states.last == monitor.state)
    let reads = monitor.reads
    stale?()
    try await Task.sleep(for: .milliseconds(100))
    #expect(monitor.reads == reads)
    let stopped = monitor.changed
    monitor.changed?()
    provider.stop()
    stopped?()
    try await Task.sleep(for: .milliseconds(100))
    #expect(monitor.reads == reads)
    #expect(states.count == 2)
    #expect(monitor.changed == nil)
  }

  @Test(
    "runtime shares monitoring and captures device changes for event, manual and interval items"
  )
  func runtime() async throws {
    let monitor = TestBluetoothMonitor()
    monitor.state = nil
    let runtime = ProviderRuntime(bluetooth: BluetoothProvider(monitor: monitor))
    defer { runtime.stop() }
    let event = Item(id: "bt-event", type: .bluetooth, refresh: RefreshPolicy(mode: .event))
    let manual = Item(id: "bt-manual", type: .bluetooth, refresh: RefreshPolicy(mode: .manual))
    let interval = Item(
      id: "bt-interval",
      type: .bluetooth,
      refresh: RefreshPolicy(mode: .interval, seconds: 3600)
    )
    let configuration = Configuration(bar: .init(), items: .init(right: [event, manual, interval]))
    runtime.configure(configuration)
    runtime.configure(configuration)
    #expect(monitor.starts == 1)
    #expect(runtime.presentation(for: manual) == nil)
    monitor.state = BluetoothState(status: .connected, devices: [.init(id: "1", name: "Keyboard")])
    monitor.changed?()
    try await Task.sleep(for: .milliseconds(150))
    #expect(runtime.presentation(for: manual)?.text == "Keyboard connected")
    monitor.state = BluetoothState(status: .connected, devices: [.init(id: "2", name: "Mouse")])
    monitor.changed?()
    try await Task.sleep(for: .milliseconds(150))
    #expect(runtime.sharedValues[.bluetooth] == "Mouse connected")
    #expect(runtime.presentation(for: event)?.text == "Mouse connected")
    #expect(runtime.presentation(for: manual)?.text == "Keyboard connected")
    #expect(runtime.presentation(for: interval)?.text == "Keyboard connected")
    runtime.trigger(manual.id)
    runtime.trigger(interval.id)
    #expect(runtime.presentation(for: manual)?.text == "Mouse connected")
    #expect(runtime.presentation(for: interval)?.text == "Mouse connected")
    runtime.configure(
      Configuration(
        bar: .init(),
        items: .init(right: [
          Item(id: "disabled", type: .group, enabled: false, children: [event])
        ])
      )
    )
    #expect(monitor.changed == nil)
    runtime.configure(configuration)
    #expect(monitor.starts == 2)
  }
}

@MainActor
private final class TestBluetoothMonitor: BluetoothMonitoring {
  var state: BluetoothState? = BluetoothState(status: .on)
  var canStart = true
  var starts = 0
  var reads = 0
  var changed: (@MainActor () -> Void)?

  func start(changed: @escaping @MainActor () -> Void) -> Bool {
    starts += 1
    self.changed = canStart ? changed : nil
    return canStart
  }

  func read() -> BluetoothState? {
    reads += 1
    return state
  }

  func stop() {
    changed = nil
  }
}
