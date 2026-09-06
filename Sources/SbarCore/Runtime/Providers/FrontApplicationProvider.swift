import AppKit

@MainActor
final class FrontApplicationProvider {
  private var observer: NSObjectProtocol?

  func start(update: @escaping @MainActor (FrontApplicationState) -> Void) {
    stop()
    update(FrontApplicationState(application: NSWorkspace.shared.frontmostApplication))
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated {
        update(FrontApplicationState(application: NSWorkspace.shared.frontmostApplication))
      }
    }
  }

  func stop() {
    if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    observer = nil
  }
}

struct FrontApplicationState {
  var name: String
  var icon: NSImage?

  init(name: String, icon: NSImage?) {
    self.name = name
    self.icon = icon
  }

  init(application: NSRunningApplication?) {
    name = application?.localizedName ?? ""
    icon = application?.icon
  }
}
