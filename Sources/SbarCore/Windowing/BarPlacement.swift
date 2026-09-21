import Foundation

struct BarPlacement {
  static func frame(screenFrame: CGRect, visibleFrame: CGRect, settings: BarSettings) -> CGRect {
    var bounds = settings.position == .top ? screenFrame : visibleFrame

    if settings.position.isVertical && settings.extendToTopEdge {
      bounds.size.height = screenFrame.maxY - bounds.minY
    }

    let left = min(settings.margin?.left ?? 0, max(0, bounds.width - 1))
    let right = min(settings.margin?.right ?? 0, max(0, bounds.width - left - 1))
    let top = min(settings.margin?.top ?? 0, max(0, bounds.height - 1))
    let bottom = min(settings.margin?.bottom ?? 0, max(0, bounds.height - top - 1))

    if settings.position.isVertical {
      let width = min(settings.width, bounds.width - left - right)

      return CGRect(
        x: settings.position == .left ? bounds.minX + left : bounds.maxX - right - width,
        y: bounds.minY + bottom,
        width: width,
        height: bounds.height - top - bottom
      )
    }

    let height = min(settings.height, bounds.height - top - bottom)

    return CGRect(
      x: bounds.minX + left,
      y: settings.position == .top ? bounds.maxY - top - height : bounds.minY + bottom,
      width: bounds.width - left - right,
      height: height
    )
  }

  /// Converts the gap between the screen's usable top areas into top-left panel coordinates.
  static func notch(screenFrame: CGRect, leftArea: CGRect?, rightArea: CGRect?, panelFrame: CGRect)
    -> CGRect?
  {
    guard let leftArea, let rightArea, rightArea.minX > leftArea.maxX else { return nil }

    let bottom = min(leftArea.minY, rightArea.minY)
    let obstruction = CGRect(
      x: leftArea.maxX,
      y: bottom,
      width: rightArea.minX - leftArea.maxX,
      height: screenFrame.maxY - bottom
    ).intersection(panelFrame)
    guard !obstruction.isNull, !obstruction.isEmpty else { return nil }

    return CGRect(
      x: obstruction.minX - panelFrame.minX,
      y: panelFrame.maxY - obstruction.maxY,
      width: obstruction.width,
      height: obstruction.height
    )
  }
}
