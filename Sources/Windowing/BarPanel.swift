import AppKit

final class BarPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hasShadow = false
        hidesOnDeactivate = false
        isExcludedFromWindowsMenu = true
        isFloatingPanel = true
        isMovable = false
        level = .statusBar
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
