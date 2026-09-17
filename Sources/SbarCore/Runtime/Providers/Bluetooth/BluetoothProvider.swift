import CoreBluetooth
import Foundation
import IOBluetooth

@MainActor
final class BluetoothProvider {
  private let monitor: any BluetoothMonitoring
  private let retryInterval: Duration
  private var update: (@MainActor (BluetoothState) -> Void)?
  private var refreshTask: Task<Void, Never>?
  private var generation = UUID()
  private var observing = false

  init(
    monitor: any BluetoothMonitoring = SystemBluetoothMonitor(),
    retryInterval: Duration = .seconds(2)
  ) {
    self.monitor = monitor
    self.retryInterval = retryInterval
  }

  func start(update: @escaping @MainActor (BluetoothState) -> Void) {
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
    // Core Bluetooth reports its initial state asynchronously, possibly after a permission prompt.
    guard let state = observing ? monitor.read() : BluetoothState() else { return }
    update(state)
    if state.status == .unavailable { scheduleRefresh(after: retryInterval) }
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
protocol BluetoothMonitoring {
  func start(changed: @escaping @MainActor () -> Void) -> Bool
  func read() -> BluetoothState?
  func stop()
}

@MainActor
final class SystemBluetoothMonitor: BluetoothMonitoring {
  static func status(_ state: CBManagerState, authorization: CBManagerAuthorization)
    -> BluetoothStatus?
  {
    if authorization == .denied || authorization == .restricted { return .unauthorized }
    switch state {
    case .unknown: return nil
    case .poweredOn: return .on
    case .poweredOff: return .off
    case .unauthorized: return .unauthorized
    case .unsupported, .resetting: return .unavailable
    @unknown default: return .unavailable
    }
  }

  private var central: CBCentralManager?
  private var callback: BluetoothCallback?
  private var connectNotification: IOBluetoothUserNotification?
  private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
  private var nameObserver: NSObjectProtocol?
  private var knownAddresses = Set<String>()
  private var generation = UUID()

  func start(changed: @escaping @MainActor () -> Void) -> Bool {
    stop()
    if CBManager.authorization == .denied || CBManager.authorization == .restricted { return true }
    guard
      let description = Bundle.main.object(
        forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription"
      ) as? String,
      !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return false }
    let generation = generation
    let callback = BluetoothCallback { [weak self] address, connected in
      guard let self, self.generation == generation else { return }
      if let address, let connected {
        if connected {
          self.knownAddresses.insert(address)
        } else {
          self.knownAddresses.remove(address)
        }
      }
      changed()
    }
    self.callback = callback
    central = CBCentralManager(
      delegate: callback,
      queue: .main,
      options: [CBCentralManagerOptionShowPowerAlertKey: false]
    )
    nameObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name(kIOBluetoothDeviceNameChangedNotification),
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.generation == generation else { return }
        changed()
      }
    }
    return true
  }

  func read() -> BluetoothState? {
    let authorization = CBManager.authorization
    guard let status = Self.status(central?.state ?? .unknown, authorization: authorization) else {
      return nil
    }
    guard status == .on else {
      clearDeviceNotifications()
      return BluetoothState(status: status)
    }
    guard let callback else { return BluetoothState() }
    if connectNotification == nil {
      connectNotification = IOBluetoothDevice.register(
        forConnectNotifications: callback,
        selector: #selector(BluetoothCallback.deviceChanged(_:device:))
      )
    }
    guard connectNotification != nil else { return BluetoothState() }
    // pairedDevices returns nil when no devices are paired. Never scan or open a connection.
    guard let paired = (IOBluetoothDevice.pairedDevices() ?? []) as? [IOBluetoothDevice] else {
      return BluetoothState()
    }
    let known = knownAddresses.compactMap { IOBluetoothDevice(addressString: $0) }
    var devices: [String: BluetoothDeviceState] = [:]
    for device in paired + known where device.isConnected() {
      guard let address = device.addressString, !address.isEmpty else { return BluetoothState() }
      devices[address] = BluetoothDeviceState(id: address, name: device.name ?? "Unnamed device")
      if disconnectNotifications[address] == nil {
        guard
          let notification = device.register(
            forDisconnectNotification: callback,
            selector: #selector(BluetoothCallback.deviceChanged(_:device:))
          )
        else { return BluetoothState() }
        disconnectNotifications[address] = notification
      }
    }
    for address in disconnectNotifications.keys.filter({ devices[$0] == nil }) {
      disconnectNotifications.removeValue(forKey: address)?.unregister()
    }
    return BluetoothState(
      status: devices.isEmpty ? .on : .connected,
      devices: devices.values.sorted { $0.id < $1.id }
    )
  }

  func stop() {
    generation = UUID()
    clearDeviceNotifications()
    if let nameObserver { NotificationCenter.default.removeObserver(nameObserver) }
    nameObserver = nil
    central?.delegate = nil
    central = nil
    callback = nil
  }

  private func clearDeviceNotifications() {
    connectNotification?.unregister()
    connectNotification = nil
    for notification in disconnectNotifications.values { notification.unregister() }
    disconnectNotifications = [:]
    knownAddresses = []
  }
}

private final class BluetoothCallback: NSObject, CBCentralManagerDelegate {
  private let changed: @MainActor @Sendable (String?, Bool?) -> Void

  init(changed: @escaping @MainActor @Sendable (String?, Bool?) -> Void) {
    self.changed = changed
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let changed = changed
    Task { @MainActor in changed(nil, nil) }
  }

  @objc func deviceChanged(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
    let changed = changed
    let address = device.addressString
    let connected = device.isConnected()
    Task { @MainActor in changed(address, connected) }
  }
}
