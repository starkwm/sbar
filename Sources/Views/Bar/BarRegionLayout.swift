import SwiftUI

/// Reserves a centered region and equal side budgets so asymmetric content cannot shift the center.
struct BarRegionLayout: Layout {
    static func widths(available: CGFloat, centerIdeal: CGFloat, spacing: CGFloat = 10) -> [CGFloat] {
        let width = max(0, available)
        let center = min(max(0, centerIdeal), width / 3)
        let gap = center > 0 ? min(spacing, (width - center) / 2) : 0
        let side = max(0, (width - center) / 2 - gap)
        return [side, center, side]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 32)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let widths = Self.widths(available: bounds.width, centerIdeal: subviews[1].sizeThatFits(.unspecified).width)
        let origins = [bounds.minX, bounds.midX - widths[1] / 2, bounds.maxX - widths[2]]
        for index in 0..<3 {
            subviews[index].place(
                at: CGPoint(x: origins[index], y: bounds.minY),
                proposal: ProposedViewSize(width: widths[index], height: bounds.height)
            )
        }
    }
}
