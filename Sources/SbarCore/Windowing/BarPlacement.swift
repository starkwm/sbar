import Foundation

struct BarPlacement {
  static func frame(screenFrame: CGRect, visibleFrame: CGRect, settings: BarSettings) -> CGRect {
    let bounds = settings.position == .top ? screenFrame : visibleFrame
    let height = min(settings.height, bounds.height)

    return CGRect(
      x: bounds.minX,
      y: settings.position == .top ? bounds.maxY - height : bounds.minY,
      width: bounds.width,
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
