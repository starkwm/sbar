import SystemConfiguration
import Testing

@testable import SbarCore

@Suite("VPN provider")
@MainActor
struct VPNProviderTests {
  @Test("recognizes registered VPNs without treating other interfaces as VPNs")
  func serviceTypes() {
    #expect(SystemVPNMonitor.isVPN(interfaceType: "VPN", underlyingType: "vendor.app"))
    #expect(SystemVPNMonitor.isVPN(interfaceType: "IPSec", underlyingType: nil))
    #expect(SystemVPNMonitor.isVPN(interfaceType: "PPP", underlyingType: "L2TP"))
    for type in ["IEEE80211", "Ethernet", "utun", "PPP", "Bridge"] {
      #expect(!SystemVPNMonitor.isVPN(interfaceType: type, underlyingType: nil))
    }
    #expect(!SystemVPNMonitor.isVPN(interfaceType: "PPP", underlyingType: "Modem"))
    #expect(!SystemVPNMonitor.isVPN(interfaceType: "PPP", underlyingType: "PPPoE"))
  }

  @Test("native status mapping preserves invalid reads as unavailable")
  func statuses() {
    #expect(SystemVPNMonitor.status(.connected) == .connected)
    #expect(SystemVPNMonitor.status(.connecting) == .connecting)
    #expect(SystemVPNMonitor.status(.disconnecting) == .disconnecting)
    #expect(SystemVPNMonitor.status(.disconnected) == .disconnected)
    #expect(SystemVPNMonitor.status(.invalid) == .unavailable)
  }

  @Test("start failures publish unavailable without reading a disconnected snapshot")
  func startFailure() {
    let monitor = TestVPNMonitor()
    monitor.canStart = false
    let provider = VPNProvider(monitor: monitor)
    defer { provider.stop() }
    var result: VPNState?
    provider.start { result = $0 }
    #expect(result == VPNState())
    #expect(monitor.reads == 0)
  }

  @Test("events coalesce and callbacks from stopped or replaced sessions are ignored")
  func lifecycle() async throws {
    let monitor = TestVPNMonitor()
    let provider = VPNProvider(monitor: monitor)
    defer { provider.stop() }
    var oldUpdates = 0
    var states: [VPNState] = []
    provider.start { _ in oldUpdates += 1 }
    let stale = monitor.changed
    provider.start { states.append($0) }
    monitor.state = VPNState(
      services: [.init(id: "x", name: "Work", status: .connected)],
      available: true
    )
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

  @Test("runtime shares VPN monitoring, snapshots events and stops disabled providers")
  func runtime() async throws {
    let monitor = TestVPNMonitor()
    let runtime = ProviderRuntime(vpn: VPNProvider(monitor: monitor))
    defer { runtime.stop() }
    let event = Item(id: "vpn-event", type: .vpn, refresh: RefreshPolicy(mode: .event))
    let manual = Item(id: "vpn-manual", type: .vpn, refresh: RefreshPolicy(mode: .manual))
    let interval = Item(
      id: "vpn-interval",
      type: .vpn,
      refresh: RefreshPolicy(mode: .interval, seconds: 3600)
    )
    let configuration = Configuration(bar: .init(), items: .init(right: [event, manual, interval]))
    runtime.configure(configuration)
    runtime.configure(configuration)
    #expect(monitor.starts == 1)
    #expect(runtime.presentation(for: manual)?.text == "VPN disconnected")
    monitor.state = VPNState(
      services: [.init(id: "x", name: "Work", status: .connected)],
      available: true
    )
    monitor.changed?()
    try await Task.sleep(for: .milliseconds(150))
    #expect(runtime.sharedValues[.vpn] == "Work connected")
    #expect(runtime.presentation(for: event)?.text == "Work connected")
    #expect(runtime.presentation(for: manual)?.text == "VPN disconnected")
    #expect(runtime.presentation(for: interval)?.text == "VPN disconnected")
    runtime.trigger(manual.id)
    runtime.trigger(interval.id)
    #expect(runtime.presentation(for: manual)?.text == "Work connected")
    #expect(runtime.presentation(for: interval)?.text == "Work connected")
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
private final class TestVPNMonitor: VPNMonitoring {
  var state = VPNState(available: true)
  var canStart = true
  var starts = 0
  var reads = 0
  var changed: (@MainActor () -> Void)?

  func start(changed: @escaping @MainActor () -> Void) -> Bool {
    starts += 1
    self.changed = canStart ? changed : nil
    return canStart
  }

  func read() -> VPNState {
    reads += 1
    return state
  }

  func stop() {
    changed = nil
  }
}
