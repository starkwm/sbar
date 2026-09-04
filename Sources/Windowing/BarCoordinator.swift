import AppKit
import ControlProtocol
import OSLog
import SwiftUI

@MainActor
final class BarCoordinator: NSObject {
    let providers: ProviderRegistry
    let actions: ActionRunner
    let events: EventBus
    private(set) var controlError: String?
    private var server: ControlServer?

    private let store: ConfigurationStore
    private var panels: [CGDirectDisplayID: BarPanel] = [:]
    private var isStarted = false
    private var sleeping = false
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    init(store: ConfigurationStore, providers: ProviderRegistry, actions: ActionRunner, events: EventBus) {
        self.providers = providers
        self.actions = actions
        self.events = events
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
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screenParametersDidChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.panels.values.forEach { $0.updateMousePolicy() }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.panels.values.forEach { $0.updateMousePolicy() } }
        }
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
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        localMouseMonitor = nil
        globalMouseMonitor = nil
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

    @objc private func willSleep() {
        sleeping = true
        providers.stop()
        actions.stop()
    }

    @objc private func didWake() {
        sleeping = false
        updatePanels()
    }

    private func updatePanels() {
        guard isStarted, !sleeping else { return }
        let configuration = store.configuration
        providers.configure(configuration)
        // The first screen is the primary display; NSScreen.main follows the key window.
        let screens: [NSScreen]
        switch configuration.bar.displays {
        case .all: screens = NSScreen.screens
        case .main: screens = Array(NSScreen.screens.prefix(1))
        case .selected:
            screens = NSScreen.screens.filter { screen in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return configuration.bar.displayIDs?.contains(id.uint32Value) == true
            }
        }
        var remaining = panels
        var updated: [CGDirectDisplayID: BarPanel] = [:]
        for screen in screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let identifier = number.uint32Value
            let frame = BarPlacement.frame(in: screen.visibleFrame, settings: configuration.bar)
            let panel = remaining.removeValue(forKey: identifier) ?? BarPanel(contentRect: frame)
            panel.setFrame(frame, display: true)
            switch configuration.bar.windowLevel ?? .statusBar {
            case .floating: panel.level = .floating
            case .statusBar: panel.level = .statusBar
            case .screenSaver: panel.level = .screenSaver
            }
            panel.passesEmptyRegions = configuration.bar.mousePassThrough ?? false
            panel.contentView = NSHostingView(rootView: BarView(configuration: configuration, hitRegionsChanged: { [weak panel] regions in panel?.hitRegions = regions; panel?.updateMousePolicy() }).environment(providers).environment(actions))
            panel.orderFrontRegardless()
            panel.updateMousePolicy()
            updated[identifier] = panel
        }
        remaining.values.forEach { $0.close() }
        panels = updated
    }
}
