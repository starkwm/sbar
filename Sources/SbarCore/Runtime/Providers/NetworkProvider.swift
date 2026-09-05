import Network

@MainActor
final class NetworkProvider {
  private var monitor: NWPathMonitor?

  func start(update: @escaping @MainActor (String, WidgetState) -> Void) {
    stop()

    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { path in
      let connected = path.status == .satisfied
      let wifi = path.usesInterfaceType(.wifi)
      let network = connected ? (wifi ? "Wi-Fi" : "Connected") : "Offline"
      let wireless = WidgetState.wifi(connected: wifi && connected)

      Task { @MainActor in update(network, wireless) }
    }
    monitor.start(queue: DispatchQueue(label: "starkbar.network"))
    self.monitor = monitor
  }

  func stop() {
    monitor?.cancel()
    monitor = nil
  }
}
