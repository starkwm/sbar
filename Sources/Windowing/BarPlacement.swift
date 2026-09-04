import Foundation

struct BarPlacement {
    static func frame(in visibleFrame: CGRect, settings: BarSettings) -> CGRect {
        let height = min(settings.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.minX,
            y: settings.position == .top ? visibleFrame.maxY - height : visibleFrame.minY,
            width: visibleFrame.width,
            height: height
        )
    }
}
