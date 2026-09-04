import AppKit

final class BarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        hasShadow = false
        hidesOnDeactivate = false
        isExcludedFromWindowsMenu = true
        isFloatingPanel = true
        isMovable = false
        isOpaque = false
        isReleasedWhenClosed = false
        isRestorable = false
        level = .statusBar
    }
}
