import AppKit

@MainActor
public enum SbarApp {
  public static func run(configurationURL: URL) {
    let app = NSApplication.shared
    let delegate = AppDelegate(configurationURL: configurationURL)
    app.setActivationPolicy(.accessory)
    app.delegate = delegate

    withExtendedLifetime(delegate) { app.run() }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let coordinator: BarCoordinator

  init(configurationURL: URL) {
    coordinator = BarCoordinator(
      store: ConfigurationStore(configurationURL: configurationURL),
      providers: ProviderRuntime(),
      actions: ActionRunner(),
      events: EventBus()
    )

    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    coordinator.start()
    if coordinator.controlError != nil { NSApp.terminate(nil) }
  }

  func applicationWillTerminate(_ notification: Notification) {
    coordinator.stop()
  }
}
