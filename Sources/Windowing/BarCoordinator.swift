import AppKit
import ControlProtocol
import OSLog
import SwiftUI

@MainActor
final class BarCoordinator: NSObject {
    let providers = ProviderRegistry()
    let actions = ActionRunner()
    let events = EventBus()
    private(set) var controlError: String?
    private var server: ControlServer?

    private let store: ConfigurationStore
    private var panels: [CGDirectDisplayID: BarPanel] = [:]
    private var isStarted = false

    init(store: ConfigurationStore) {
        self.store = store
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        store.startObserving()
        store.configurationDidChange = { [weak self] in
            self?.updatePanels()
            self?.events.emit(RuntimeEvent(kind: .configuration, name: "configuration", value: nil))
        }
        providers.onValueChange = { [weak self] name, value in
            self?.events.emit(RuntimeEvent(kind: .provider, name: name, value: .string(value)))
        }
        let router = ControlRouter(store: store, providers: providers, events: events)
        let server = ControlServer(path: store.configurationURL.deletingLastPathComponent().appending(path: "control.sock").path) { request in
            await router.handle(request)
        }
        events.onEvent = { [weak server] event in
            if let data = try? JSONEncoder().encode(event), let value = try? JSONDecoder().decode(JSONValue.self, from: data) {
                server?.publish(ControlResponse(value: value))
            }
        }
        do { try server.start(); self.server = server } catch {
            controlError = error.localizedDescription
            Logger(subsystem: "com.starkwm.StarkBar", category: "control").error("Control server failed: \(error.localizedDescription, privacy: .public)")
        }
        updatePanels()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        server?.stop()
        server = nil
        events.onEvent = nil
        actions.stop()
        providers.onValueChange = nil
        providers.stop()
        store.stopObserving()
        store.configurationDidChange = nil
        panels.values.forEach { $0.close() }
        panels.removeAll()
        isStarted = false
    }

    func reload() {
        store.load()
    }

    @objc private func screenParametersDidChange() {
        updatePanels()
    }

    private func updatePanels() {
        guard isStarted else { return }
        let configuration = store.configuration
        providers.configure(configuration)
        // The first screen is the primary display; NSScreen.main follows the key window.
        let screens = configuration.bar.displays == .all ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        var remaining = panels
        var updated: [CGDirectDisplayID: BarPanel] = [:]
        for screen in screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let identifier = number.uint32Value
            let frame = BarPlacement.frame(in: screen.visibleFrame, settings: configuration.bar)
            let panel = remaining.removeValue(forKey: identifier) ?? BarPanel(contentRect: frame)
            panel.setFrame(frame, display: true)
            panel.contentView = NSHostingView(rootView: BarView(configuration: configuration).environment(providers).environment(actions))
            panel.orderFrontRegardless()
            updated[identifier] = panel
        }
        remaining.values.forEach { $0.close() }
        panels = updated
    }
}
