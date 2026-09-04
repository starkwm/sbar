import AppKit
import SwiftUI

@main
struct StarkBarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("StarkBar", systemImage: "rectangle.topthird.inset.filled") {
            Button("Reload Configuration") { appDelegate.reload() }
            SettingsLink()
            Divider()
            Button("Quit StarkBar") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        Settings {
            SettingsView(store: appDelegate.store) { appDelegate.reload() }
                .environment(appDelegate.providers)
                .environment(appDelegate.actions)
                .environment(appDelegate.events)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigurationStore()
    let providers = ProviderRegistry()
    let actions = ActionRunner()
    let events = EventBus()
    private var coordinator: BarCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator = BarCoordinator(store: store, providers: providers, actions: actions, events: events)
        coordinator?.start()
    }

    func reload() { coordinator?.reload() }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}
