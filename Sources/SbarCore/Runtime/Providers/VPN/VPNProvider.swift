import Foundation
import SystemConfiguration

@MainActor
final class VPNProvider {
  private let monitor: any VPNMonitoring
  private var update: (@MainActor (VPNState) -> Void)?
  private var refreshTask: Task<Void, Never>?
  private var generation = UUID()
  private var observing = false

  init(monitor: any VPNMonitoring = SystemVPNMonitor()) {
    self.monitor = monitor
  }

  func start(update: @escaping @MainActor (VPNState) -> Void) {
    stop()
    self.update = update
    refresh()
  }

  func stop() {
    generation = UUID()
    refreshTask?.cancel()
    refreshTask = nil
    monitor.stop()
    observing = false
    update = nil
  }

  private func refresh() {
    guard let update else { return }

    if !observing {
      let generation = generation
      observing = monitor.start { [weak self] in
        guard let self, self.generation == generation else { return }

        self.scheduleRefresh()
      }
    }

    let state = observing ? monitor.read() : VPNState()
    update(state)

    if state.status == .unavailable { scheduleRefresh(after: .seconds(2)) }
  }

  private func scheduleRefresh(after delay: Duration = .milliseconds(50)) {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      do { try await Task.sleep(for: delay) } catch { return }

      guard let self, !Task.isCancelled else { return }

      self.refreshTask = nil
      self.refresh()
    }
  }
}

@MainActor
protocol VPNMonitoring {
  func start(changed: @escaping @MainActor () -> Void) -> Bool
  func read() -> VPNState
  func stop()
}

@MainActor
final class SystemVPNMonitor: VPNMonitoring {
  static func isVPN(interfaceType: String, underlyingType: String?) -> Bool {
    // Network Extension services expose the type "VPN" without a public constant.
    interfaceType == "VPN" || interfaceType == kSCNetworkInterfaceTypeIPSec as String
      || (interfaceType == kSCNetworkInterfaceTypePPP as String
        && underlyingType == kSCNetworkInterfaceTypeL2TP as String)
  }

  static func status(_ status: SCNetworkConnectionStatus) -> VPNStatus {
    switch status {
    case .connected: .connected
    case .connecting: .connecting
    case .disconnecting: .disconnecting
    case .disconnected: .disconnected
    case .invalid: .unavailable
    @unknown default: .unavailable
    }
  }

  private var preferences: SCPreferences?
  private var connections: [String: SCNetworkConnection] = [:]
  private var handler: VPNChangeHandler?

  func start(changed: @escaping @MainActor () -> Void) -> Bool {
    stop()
    let handler = VPNChangeHandler(changed: changed)
    self.handler = handler
    guard let preferences = SCPreferencesCreate(nil, "sbar.vpn" as CFString, nil) else {
      return false
    }

    self.preferences = preferences
    var context = SCPreferencesContext(
      version: 0,
      info: Unmanaged.passUnretained(handler).toOpaque(),
      retain: { @Sendable info in VPNChangeHandler.retain(info) },
      release: { @Sendable info in VPNChangeHandler.release(info) },
      copyDescription: nil
    )
    guard
      SCPreferencesSetCallback(
        preferences,
        { @Sendable preferences, notification, info in
          VPNChangeHandler.preferencesChanged(preferences, notification, info)
        },
        &context
      ), SCPreferencesSetDispatchQueue(preferences, .main)
    else {
      stop()

      return false
    }

    return true
  }

  func read() -> VPNState {
    guard let preferences, let handler else { return VPNState() }

    SCPreferencesSynchronize(preferences)
    guard let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
      return VPNState()
    }

    var entries: [VPNServiceState] = []
    var observed = Set<String>()

    for service in services where SCNetworkServiceGetEnabled(service) {
      guard let interface = SCNetworkServiceGetInterface(service),
        let type = SCNetworkInterfaceGetInterfaceType(interface) as String?
      else { continue }

      let underlying = SCNetworkInterfaceGetInterface(interface).flatMap {
        SCNetworkInterfaceGetInterfaceType($0) as String?
      }
      guard Self.isVPN(interfaceType: type, underlyingType: underlying) else { continue }
      guard let id = SCNetworkServiceGetServiceID(service) else { return VPNState() }

      let name = SCNetworkServiceGetName(service) as String? ?? "VPN"
      let key = id as String
      observed.insert(key)
      var context = SCNetworkConnectionContext(
        version: 0,
        info: Unmanaged.passUnretained(handler).toOpaque(),
        retain: { @Sendable info in VPNChangeHandler.retain(info) },
        release: { @Sendable info in VPNChangeHandler.release(info) },
        copyDescription: nil
      )
      var status = VPNStatus.unavailable

      if let connection = connections[key] {
        status = Self.status(SCNetworkConnectionGetStatus(connection))
      } else if let connection = SCNetworkConnectionCreateWithServiceID(
        nil,
        id,
        { @Sendable connection, status, info in
          VPNChangeHandler.connectionChanged(connection, status, info)
        },
        &context
      ) {
        // Read before subscribing: registration can briefly report a cached disconnected state.
        let initial = Self.status(SCNetworkConnectionGetStatus(connection))

        if SCNetworkConnectionSetDispatchQueue(connection, .main) {
          connections[key] = connection
          status = initial
        }
      }

      entries.append(VPNServiceState(id: key, name: name, status: status))
    }
    for id in connections.keys.filter({ !observed.contains($0) }) {
      if let connection = connections.removeValue(forKey: id) {
        SCNetworkConnectionSetDispatchQueue(connection, nil)
      }
    }

    return VPNState(services: entries.sorted { $0.id < $1.id }, available: true)
  }

  func stop() {
    clearConnections()

    if let preferences {
      SCPreferencesSetDispatchQueue(preferences, nil)
      SCPreferencesSetCallback(preferences, nil, nil)
    }

    preferences = nil
    handler = nil
  }

  private func clearConnections() {
    for connection in connections.values { SCNetworkConnectionSetDispatchQueue(connection, nil) }

    connections = [:]
  }
}

// Core Foundation can retain and release callback contexts on its own queues.
private final class VPNChangeHandler: Sendable {
  static func retain(_ info: UnsafeRawPointer) -> UnsafeRawPointer {
    UnsafeRawPointer(Unmanaged<VPNChangeHandler>.fromOpaque(info).retain().toOpaque())
  }

  static func release(_ info: UnsafeRawPointer) {
    Unmanaged<VPNChangeHandler>.fromOpaque(info).release()
  }

  static func preferencesChanged(
    _ preferences: SCPreferences,
    _ notification: SCPreferencesNotification,
    _ info: UnsafeMutableRawPointer?
  ) {
    notify(info)
  }

  static func connectionChanged(
    _ connection: SCNetworkConnection,
    _ status: SCNetworkConnectionStatus,
    _ info: UnsafeMutableRawPointer?
  ) {
    notify(info)
  }

  private static func notify(_ info: UnsafeMutableRawPointer?) {
    guard let info else { return }

    let handler = Unmanaged<VPNChangeHandler>.fromOpaque(info).takeUnretainedValue()
    Task { @MainActor in handler.changed() }
  }

  let changed: @MainActor @Sendable () -> Void

  init(changed: @escaping @MainActor @Sendable () -> Void) {
    self.changed = changed
  }
}
