import SwiftUI

/// Centers content on unobstructed displays; beside a notch, center and right share the right-hand area.
struct BarRegionLayout: Layout {
    static func widths(available: CGFloat, centerIdeal: CGFloat, spacing: CGFloat = 10) -> [CGFloat] {
        let width = max(0, available)
        let center = min(max(0, centerIdeal), width / 3)
        let gap = center > 0 ? min(spacing, (width - center) / 2) : 0
        let side = max(0, (width - center) / 2 - gap)
        return [side, center, side]
    }

    static func frames(in bounds: CGRect, hasCenter: Bool, notch: CGRect?) -> [CGRect] {
        if let notch {
            let leftEnd = min(bounds.maxX, max(bounds.minX, bounds.minX + notch.minX - 8))
            let rightStart = min(bounds.maxX, max(bounds.minX, bounds.minX + notch.maxX + 8))
            let rightWidth = bounds.maxX - rightStart
            let gap = hasCenter ? min(10, rightWidth) : 0
            let centerWidth = hasCenter ? (rightWidth - gap) / 2 : 0
            let trailingStart = rightStart + centerWidth + gap
            return [
                CGRect(x: bounds.minX, y: bounds.minY, width: leftEnd - bounds.minX, height: bounds.height),
                CGRect(x: rightStart, y: bounds.minY, width: centerWidth, height: bounds.height),
                CGRect(x: trailingStart, y: bounds.minY, width: bounds.maxX - trailingStart, height: bounds.height),
            ]
        }
        let widths = Self.widths(available: bounds.width, centerIdeal: hasCenter ? bounds.width / 3 : 0)
        let origins = [bounds.minX, bounds.midX - widths[1] / 2, bounds.maxX - widths[2]]
        return (0..<3).map { CGRect(x: origins[$0], y: bounds.minY, width: widths[$0], height: bounds.height) }
    }

    var hasCenter = true
    var notch: CGRect?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 32)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let frames = Self.frames(in: bounds, hasCenter: hasCenter, notch: notch)
        for index in 0..<3 {
            subviews[index].place(
                at: frames[index].origin,
                proposal: ProposedViewSize(width: frames[index].width, height: frames[index].height)
            )
        }
    }
}
