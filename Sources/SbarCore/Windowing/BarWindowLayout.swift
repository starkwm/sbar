import Foundation

struct BarWindowLayout {
  static let edgeShadowExtent: CGFloat = 16

  let frame: CGRect
  let contentFrame: CGRect
  let shadowExtent: CGFloat
  let position: BarPosition
  let hasNativeShadow: Bool

  init(
    screenFrame: CGRect,
    barFrame: CGRect,
    position: BarPosition,
    shadow: Bool,
    cornerRadius: Double
  ) {
    self.position = position
    let edgeToEdge =
      position.isVertical
      ? barFrame.minY <= screenFrame.minY && barFrame.maxY >= screenFrame.maxY
      : barFrame.minX <= screenFrame.minX && barFrame.maxX >= screenFrame.maxX
    let usesEdgeShadow = shadow && edgeToEdge && cornerRadius == 0
    let available: CGFloat

    switch position {
    case .top: available = barFrame.minY - screenFrame.minY
    case .bottom: available = screenFrame.maxY - barFrame.maxY
    case .left: available = screenFrame.maxX - barFrame.maxX
    case .right: available = barFrame.minX - screenFrame.minX
    }

    shadowExtent = usesEdgeShadow ? min(Self.edgeShadowExtent, max(0, available)) : 0
    hasNativeShadow = shadow && !usesEdgeShadow

    frame = CGRect(
      x: barFrame.minX - (position == .right ? shadowExtent : 0),
      y: barFrame.minY - (position == .top ? shadowExtent : 0),
      width: barFrame.width + (position.isVertical ? shadowExtent : 0),
      height: barFrame.height + (position.isVertical ? 0 : shadowExtent)
    )
    // SwiftUI and item hit regions use top-left coordinates within the panel.
    contentFrame = CGRect(
      x: position == .right ? shadowExtent : 0,
      y: position == .bottom ? shadowExtent : 0,
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
