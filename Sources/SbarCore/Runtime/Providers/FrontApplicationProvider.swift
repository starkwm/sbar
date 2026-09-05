import AppKit

@MainActor
final class FrontApplicationProvider {
  private var observer: NSObjectProtocol?

  func start(update: @escaping @MainActor (String) -> Void) {
    stop()
    update(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated {
        update(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")
      }
    }
  }

  func stop() {
    if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    observer = nil
  }
}
