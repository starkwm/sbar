import Network

@MainActor
final class NetworkProvider {
  private var monitor: NWPathMonitor?

  func start(update: @escaping @MainActor (WidgetState) -> Void) {
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

      Task { @MainActor in update(network) }
    }
    monitor.start(queue: DispatchQueue(label: "starkbar.network"))
    self.monitor = monitor
  }

  func stop() {
    monitor?.cancel()
    monitor = nil
  }
}
