import Network

@MainActor
final class NetworkProvider {
  private var monitor: NWPathMonitor?

  func start(update: @escaping @MainActor (WidgetState, WidgetState) -> Void) {
    stop()

    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { path in
      let connected = path.status == .satisfied
      let wifi = path.usesInterfaceType(.wifi)
      let connection = NetworkConnection.classify(
        connected: connected,
        wifi: wifi,
        ethernet: path.usesInterfaceType(.wiredEthernet),
        cellular: path.usesInterfaceType(.cellular)
      )
      let network = WidgetState.network(connection)
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
