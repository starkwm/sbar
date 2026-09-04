import AppKit

final class BarPanel: NSPanel {
    var hitRegions: [CGRect] = []
    var passesEmptyRegions = false

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
        acceptsMouseMovedEvents = true
        level = .statusBar
    }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func updateMousePolicy() {
        let local = convertPoint(fromScreen: NSEvent.mouseLocation)
        let point = CGPoint(x: local.x, y: frame.height - local.y)
        ignoresMouseEvents = passesEmptyRegions && !hitRegions.contains { $0.contains(point) }
    }
}
