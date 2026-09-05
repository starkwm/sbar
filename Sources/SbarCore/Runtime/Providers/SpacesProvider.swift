import AppKit

@MainActor
final class SpacesProvider {
  private struct API {
    let connection: @convention(c) () -> Int32
    let activeSpace: @convention(c) (Int32) -> UInt64
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
      displaySpaces: unsafeBitCast(
        displaySpaces,
        to: (@convention(c) (Int32) -> Unmanaged<CFArray>?).self
      )
    )
  }()

  static func label(displays: [[String: Any]], activeSpaceID: UInt64) -> String {
    var identifiers: [UInt64] = []
    var seen = Set<UInt64>()

    for display in displays {
      for space in display["Spaces"] as? [[String: Any]] ?? [] {
        guard let number = space["ManagedSpaceID"] as? NSNumber else { continue }
        let id = number.uint64Value
        guard id != 0, seen.insert(id).inserted else { continue }

        identifiers.append(id)
      }
    }

    guard let index = identifiers.firstIndex(of: activeSpaceID) else { return "Spaces unavailable" }

    return String(index + 1)
  }

  static func currentLabel() -> String {
    guard let api else { return "Spaces unavailable" }

    let connection = api.connection()
    guard let data = api.displaySpaces(connection)?.takeRetainedValue(),
      let displays = data as? [[String: Any]]
    else { return "Spaces unavailable" }

    return label(displays: displays, activeSpaceID: api.activeSpace(connection))
  }

  private var observers: [(NotificationCenter, NSObjectProtocol)] = []

  func start(update: @escaping @MainActor (String) -> Void) {
    stop()
    update(Self.currentLabel())

    let workspace = NSWorkspace.shared.notificationCenter
    for (center, name) in [
      (workspace, NSWorkspace.activeSpaceDidChangeNotification),
      (workspace, NSWorkspace.didActivateApplicationNotification),
      (NotificationCenter.default, NSApplication.didChangeScreenParametersNotification),
    ] {
      let observer = center.addObserver(forName: name, object: nil, queue: .main) { _ in
        MainActor.assumeIsolated { update(Self.currentLabel()) }
      }
      observers.append((center, observer))
    }
  }

  func stop() {
    for (center, observer) in observers { center.removeObserver(observer) }
    observers.removeAll()
  }
}
