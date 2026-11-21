import Foundation
import Network

@MainActor
final class NetworkProvider {
  private let makeMonitor: @MainActor () -> any NetworkPathMonitoring
  private var monitor: (any NetworkPathMonitoring)?
  private var generation = UUID()

  init(
    makeMonitor: @escaping @MainActor () -> any NetworkPathMonitoring = {
      SystemNetworkPathMonitor()
    }
  ) {
    self.makeMonitor = makeMonitor
  }

  func start(update: @escaping @MainActor (WidgetState) -> Void) {
    stop()

    let generation = generation
    let monitor = makeMonitor()
    monitor.start { [weak self] connection in
      Task { @MainActor in
        // A stop or restart may run before this queued update.
        guard let self, self.generation == generation else { return }

        update(.network(connection))
      }
    }
    self.monitor = monitor
  }

  func stop() {
    generation = UUID()
    monitor?.cancel()
    monitor = nil
  }
}

@MainActor
protocol NetworkPathMonitoring {
  func start(changed: @escaping @Sendable (NetworkConnection) -> Void)
  func cancel()
}

@MainActor
final class SystemNetworkPathMonitor: NetworkPathMonitoring {
  private let monitor = NWPathMonitor()

  func start(changed: @escaping @Sendable (NetworkConnection) -> Void) {
    monitor.pathUpdateHandler = { path in
      changed(
        NetworkConnection.classify(
          connected: path.status == .satisfied,
          wifi: path.usesInterfaceType(.wifi),
          ethernet: path.usesInterfaceType(.wiredEthernet),
          cellular: path.usesInterfaceType(.cellular)
        )
      )
    }
    monitor.start(queue: DispatchQueue(label: "sbar.network"))
  }

  func cancel() { monitor.cancel() }
}
