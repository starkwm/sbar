import AppKit
import SwiftUI

@MainActor
final class BarCoordinator: NSObject {
    let providers = ProviderRegistry()
    let actions = ActionRunner()

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
        store.configurationDidChange = { [weak self] in self?.updatePanels() }
        updatePanels()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        actions.stop()
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
