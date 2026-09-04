import AppKit
import SwiftUI

@MainActor
final class BarCoordinator: NSObject {
    private let store: ConfigurationStore
    private var panels: [BarPanel] = []

    init(store: ConfigurationStore) {
        self.store = store
        super.init()
    }

    func start() {
        store.load()
        rebuildPanels()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func reload() {
        store.load()
        rebuildPanels()
    }

    @objc private func screenParametersDidChange() {
        rebuildPanels()
    }

    private func rebuildPanels() {
        panels.forEach { $0.close() }
        let configuration = store.configuration
        panels = selectedScreens(for: configuration.bar.displays).map { screen in
            let panel = BarPanel(contentRect: frame(for: screen, settings: configuration.bar))
            panel.contentView = NSHostingView(rootView: BarView(configuration: configuration))
            panel.orderFrontRegardless()
            return panel
        }
    }

    private func selectedScreens(for selection: DisplaySelection) -> [NSScreen] {
        switch selection {
        case .all: NSScreen.screens
        case .main: NSScreen.main.map { [$0] } ?? []
        }
    }

    private func frame(for screen: NSScreen, settings: BarSettings) -> NSRect {
        switch settings.position {
        case .top:
            let screenFrame = screen.frame
            return NSRect(
                x: screenFrame.minX,
                y: screenFrame.maxY - settings.height,
                width: screenFrame.width,
                height: settings.height
            )
        case .bottom:
            let visibleFrame = screen.visibleFrame
            return NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: settings.height
            )
        }
    }
}
