import Foundation

struct BarWindowLayout {
  static let edgeShadowExtent: CGFloat = 16

  let frame: CGRect
  let contentFrame: CGRect
  let shadowExtent: CGFloat
  let shadowAbove: Bool
  let hasNativeShadow: Bool

  init(
    screenFrame: CGRect,
    barFrame: CGRect,
    position: BarPosition,
    shadow: Bool,
    cornerRadius: Double
  ) {
    let edgeToEdge = barFrame.minX <= screenFrame.minX && barFrame.maxX >= screenFrame.maxX
    let usesEdgeShadow = shadow && edgeToEdge && cornerRadius == 0
    let available =
      position == .top
      ? barFrame.minY - screenFrame.minY : screenFrame.maxY - barFrame.maxY
    shadowExtent = usesEdgeShadow ? min(Self.edgeShadowExtent, max(0, available)) : 0
    shadowAbove = position == .bottom
    hasNativeShadow = shadow && !usesEdgeShadow

    frame = CGRect(
      x: barFrame.minX,
      y: barFrame.minY - (shadowAbove ? 0 : shadowExtent),
      width: barFrame.width,
      height: barFrame.height + shadowExtent
    )
    // SwiftUI and item hit regions use top-left coordinates within the panel.
    contentFrame = CGRect(
      x: 0,
      y: shadowAbove ? shadowExtent : 0,
      width: barFrame.width,
      height: barFrame.height
    )
  }

  func ignoresMouse(at point: CGPoint, passingThroughEmptyRegions: Bool, hitRegions: [CGRect])
    -> Bool
  {
    guard contentFrame.contains(point) else { return true }
    let contentPoint = CGPoint(x: point.x - contentFrame.minX, y: point.y - contentFrame.minY)
    return passingThroughEmptyRegions && !hitRegions.contains { $0.contains(contentPoint) }
  }
}
