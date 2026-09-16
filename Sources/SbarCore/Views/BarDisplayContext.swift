import SwiftUI

extension EnvironmentValues {
  @Entry var barPosition: BarPosition = .top
  @Entry var barDisplayUUID: String? = nil
}

extension BarPosition {
  var popoverEdge: Edge? {
    // The edge belongs to the source item. Side bars attach towards the display interior.
    switch self {
    case .top, .bottom: nil
    case .left: .trailing
    case .right: .leading
    }
  }

  func stack(spacing: CGFloat) -> AnyLayout {
    isVertical
      ? AnyLayout(VStackLayout(spacing: spacing))
      : AnyLayout(HStackLayout(spacing: spacing))
  }
}
