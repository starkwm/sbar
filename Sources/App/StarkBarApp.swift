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
    let store: ConfigurationStore
    let providers = ProviderRegistry()
    let actions = ActionRunner()
    let events = EventBus()
    private let startupError: String?
    private var coordinator: BarCoordinator?

    override init() {
        do {
            let options = try StartupOptions.parse(Array(CommandLine.arguments.dropFirst()))
            store = ConfigurationStore(configurationURL: options.configurationURL)
            startupError = nil
        } catch {
            store = ConfigurationStore()
            startupError = error.localizedDescription
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let startupError {
            FileHandle.standardError.write(Data((startupError + "\n").utf8))
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        coordinator = BarCoordinator(store: store, providers: providers, actions: actions, events: events)
        coordinator?.start()
        if coordinator?.controlError != nil { NSApp.terminate(nil) }
    }

    func reload() { coordinator?.reload() }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}
