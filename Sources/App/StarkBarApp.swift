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
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigurationStore()
    private var coordinator: BarCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator = BarCoordinator(store: store)
        coordinator?.start()
    }

    func reload() { coordinator?.reload() }
}
