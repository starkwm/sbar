import AppKit
import SwiftUI

public struct SbarApp: App {
  static var configurationURL = FileManager.default.homeDirectoryForCurrentUser.appending(
    path: ".config/starkbar/config.json"
  )

  public static func run(configurationURL: URL) {
    self.configurationURL = configurationURL
    main()
  }

  public var body: some Scene {
    MenuBarExtra("sbar", systemImage: "rectangle.topthird.inset.filled") {
      Button("Reload Configuration") { appDelegate.reload() }
      SettingsLink()
      Divider()
      Button("Quit sbar") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
    Settings {
      SettingsView(store: appDelegate.store) { appDelegate.reload() }
        .environment(appDelegate.providers)
        .environment(appDelegate.actions)
        .environment(appDelegate.events)
    }
  }

  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

  public init() {}

}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let store: ConfigurationStore
  let providers = ProviderRegistry()
  let actions = ActionRunner()
  let events = EventBus()
  private var coordinator: BarCoordinator?

  override init() {
    store = ConfigurationStore(configurationURL: SbarApp.configurationURL)
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    coordinator = BarCoordinator(
      store: store,
      providers: providers,
      actions: actions,
      events: events
    )
    coordinator?.start()
    if coordinator?.controlError != nil { NSApp.terminate(nil) }
  }

  func reload() { coordinator?.reload() }

  func applicationWillTerminate(_ notification: Notification) {
    coordinator?.stop()
  }
}
