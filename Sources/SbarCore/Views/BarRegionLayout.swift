import SwiftUI

/// Centers content on unobstructed displays; beside a notch, center and right share the right-hand area.
struct BarRegionLayout: Layout {
  static func lengths(available: CGFloat, centerIdeal: CGFloat, spacing: CGFloat = 10) -> [CGFloat]
  {
    let length = max(0, available)
    let center = min(max(0, centerIdeal), length / 3)
    let gap = center > 0 ? min(spacing, (length - center) / 2) : 0
    let side = max(0, (length - center) / 2 - gap)

    return [side, center, side]
  }

  static func frames(
    in bounds: CGRect,
    hasCenter: Bool,
    notch: CGRect?,
    isVertical: Bool = false
  ) -> [CGRect] {
    if let notch, !isVertical {
      let leftEnd = min(bounds.maxX, max(bounds.minX, bounds.minX + notch.minX - 8))
      let rightStart = min(bounds.maxX, max(bounds.minX, bounds.minX + notch.maxX + 8))
      let rightWidth = bounds.maxX - rightStart
      let gap = hasCenter ? min(10, rightWidth) : 0
      let centerWidth = hasCenter ? (rightWidth - gap) / 2 : 0
      let trailingStart = rightStart + centerWidth + gap

      return [
        CGRect(x: bounds.minX, y: bounds.minY, width: leftEnd - bounds.minX, height: bounds.height),
        CGRect(x: rightStart, y: bounds.minY, width: centerWidth, height: bounds.height),
        CGRect(
          x: trailingStart,
          y: bounds.minY,
          width: bounds.maxX - trailingStart,
          height: bounds.height
        ),
      ]
    }

    let available = isVertical ? bounds.height : bounds.width
    let lengths = Self.lengths(available: available, centerIdeal: hasCenter ? available / 3 : 0)
    let offsets = [0, (available - lengths[1]) / 2, available - lengths[2]]

    return (0..<3).map { index in
      if isVertical {
        CGRect(
          x: bounds.minX,
          y: bounds.minY + offsets[index],
          width: bounds.width,
          height: lengths[index]
        )
      } else {
        CGRect(
          x: bounds.minX + offsets[index],
          y: bounds.minY,
          width: lengths[index],
          height: bounds.height
        )
      }
    }
  }

  var hasCenter = true
  var notch: CGRect?
  var isVertical = false

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    CGSize(
      width: proposal.width ?? (isVertical ? 32 : 0),
      height: proposal.height ?? (isVertical ? 0 : 32)
    )
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    guard subviews.count == 3 else { return }

    let frames = Self.frames(in: bounds, hasCenter: hasCenter, notch: notch, isVertical: isVertical)

    for index in 0..<3 {
      subviews[index].place(
        at: frames[index].origin,
        proposal: ProposedViewSize(width: frames[index].width, height: frames[index].height)
      )
    }
  }
}
