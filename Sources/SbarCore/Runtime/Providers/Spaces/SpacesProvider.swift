import AppKit

@MainActor
final class SpacesProvider {
  private struct API {
    let connection: @convention(c) () -> Int32
    let activeSpace: @convention(c) (Int32) -> UInt64
    let currentSpace: (@convention(c) (Int32, CFString) -> UInt64)?
    let displaySpaces: @convention(c) (Int32) -> Unmanaged<CFArray>?
  }

  // Keep SkyLight loaded for the lifetime of these function pointers.
  private static let api: API? = {
    guard
      let handle = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        RTLD_LAZY | RTLD_LOCAL
      )
    else { return nil }

    guard let connection = dlsym(handle, "SLSMainConnectionID"),
      let activeSpace = dlsym(handle, "SLSGetActiveSpace"),
      let displaySpaces = dlsym(handle, "SLSCopyManagedDisplaySpaces")
    else {
      dlclose(handle)
      return nil
    }

    return API(
      connection: unsafeBitCast(connection, to: (@convention(c) () -> Int32).self),
      activeSpace: unsafeBitCast(activeSpace, to: (@convention(c) (Int32) -> UInt64).self),
      currentSpace: dlsym(handle, "SLSManagedDisplayGetCurrentSpace").map {
        unsafeBitCast($0, to: (@convention(c) (Int32, CFString) -> UInt64).self)
      },
      displaySpaces: unsafeBitCast(
        displaySpaces,
        to: (@convention(c) (Int32) -> Unmanaged<CFArray>?).self
      )
    )
  }()

  static func label(displays: [[String: Any]], activeSpaceID: UInt64) -> String {
    SpacesState.parse(displays: displays, activeSpaceID: activeSpaceID).text
  }

  static func currentState() -> SpacesState {
    guard let api else { return SpacesState() }
    let connection = api.connection()
    guard let data = api.displaySpaces(connection)?.takeRetainedValue(),
      var displays = data as? [[String: Any]]
    else { return SpacesState() }
    if let currentSpace = api.currentSpace {
      for index in displays.indices {
        if let identifier = displays[index]["Display Identifier"] as? String {
          let current = currentSpace(connection, identifier as CFString)
          if current != 0 { displays[index]["Current Space"] = ["ManagedSpaceID": current] }
        }
      }
    }
    return SpacesState.parse(displays: displays, activeSpaceID: api.activeSpace(connection))
  }

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
    application: NotificationCenter = .default
  ) {
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
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
      }
    }
  }
}
