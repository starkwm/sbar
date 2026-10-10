import AppKit

@MainActor
final class FrontApplicationProvider {
  typealias ObserveApplication =
    @MainActor (@escaping @MainActor (NSRunningApplication?) -> Void) -> NSKeyValueObservation

  private let observeApplication: ObserveApplication
  private var observation: NSKeyValueObservation?

  init(
    observeApplication: @escaping ObserveApplication = { update in
      // Accessory launchers can remain frontmost after dismissing their windows.
      // Menu ownership continues to identify the underlying application.
      NSWorkspace.shared.observe(
        \.menuBarOwningApplication,
        options: [.initial, .new]
      ) { _, change in
        let application = change.newValue ?? nil
        MainActor.assumeIsolated { update(application) }
      }
    }
  ) {
    self.observeApplication = observeApplication
  }

  func start(update: @escaping @MainActor (FrontApplicationState) -> Void) {
    stop()
    observation = observeApplication { application in
      update(FrontApplicationState(application: application))
    }
  }

  func stop() {
    observation?.invalidate()
    observation = nil
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
