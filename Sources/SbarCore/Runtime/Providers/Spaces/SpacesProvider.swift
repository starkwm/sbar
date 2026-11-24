import AppKit
import StarkSkyLight

@MainActor
final class SpacesProvider {
  private static var client: SpaceClient?

  static func currentState() -> SpacesState {
    if client == nil { client = try? SpaceClient() }
    guard let client else { return SpacesState() }

    return currentState(using: client)
  }

  static func currentState(using client: any SpaceQuerying) -> SpacesState {
    guard let snapshot = try? client.snapshot() else { return SpacesState() }

    let displays = snapshot.displays.map { display in
      let identifier = display.id.rawValue.lowercased()
      let current =
        (try? client.currentSpace(for: display.id)) ?? display.currentSpaceID
        ?? (identifier == "main" ? snapshot.activeSpaceID : nil)

      return SpaceDisplay(
        identifier: identifier,
        spaces: display.spaces.map {
          SpaceEntry(id: $0.id.rawValue, fullscreen: $0.type == .fullscreen)
        },
        activeID: current?.rawValue
      )
    }

    return SpacesState(displays: displays, focusedID: snapshot.activeSpaceID?.rawValue ?? 0)
  }

  private let retryInterval: Duration
  private let query: @MainActor () -> SpacesState
  private let workspace: NotificationCenter
  private let application: NotificationCenter
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []
  private var refreshTask: Task<Void, Never>?
  private var update: (@MainActor (SpacesState) -> Void)?
  private var generation = UUID()

  init(
    query: @escaping @MainActor () -> SpacesState = SpacesProvider.currentState,
    workspace: NotificationCenter = NSWorkspace.shared.notificationCenter,
    application: NotificationCenter = .default,
    retryInterval: Duration = .milliseconds(100)
  ) {
    self.retryInterval = retryInterval
    self.query = query
    self.workspace = workspace
    self.application = application
  }

  func start(update: @escaping @MainActor (SpacesState) -> Void) {
    stop()
    self.update = update
    let initial = query()
    update(initial)

    if !initial.complete { scheduleRefresh() }

    let generation = generation

    for (center, name) in [
      (workspace, NSWorkspace.activeSpaceDidChangeNotification),
      (workspace, NSWorkspace.didActivateApplicationNotification),
      (application, NSApplication.didChangeScreenParametersNotification),
    ] {
      let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, self.generation == generation else { return }

          self.scheduleRefresh()
        }
      }
      observers.append((center, observer))
    }
  }

  func stop() {
    generation = UUID()
    refreshTask?.cancel()
    refreshTask = nil

    for (center, observer) in observers { center.removeObserver(observer) }

    observers = []
    update = nil
  }

  private func scheduleRefresh() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
      for attempt in 0..<4 {
        guard let self, !Task.isCancelled else { return }

        let state = self.query()

        if state.complete || attempt == 3 {
          self.update?(state)

          return
        }
        do { try await Task.sleep(for: self.retryInterval) } catch { return }
      }
    }
  }
}
