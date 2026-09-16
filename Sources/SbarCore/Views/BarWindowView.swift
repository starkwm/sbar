import SwiftUI

struct BarWindowView: View {
  let configuration: Configuration
  let layout: BarWindowLayout
  var notch: CGRect?
  var hitRegionsChanged: (([CGRect]) -> Void)?

  var body: some View {
    ZStack(alignment: .topLeading) {
      edgeShadow
      BarView(configuration: configuration, notch: notch, hitRegionsChanged: hitRegionsChanged)
        .frame(width: layout.contentFrame.width, height: layout.contentFrame.height)
        .offset(x: layout.contentFrame.minX, y: layout.contentFrame.minY)
    }
    .frame(width: layout.frame.width, height: layout.frame.height, alignment: .topLeading)
  }

  private var edgeShadow: some View {
    LinearGradient(
      stops: [
        .init(color: .black.opacity(0.24), location: 0),
        .init(color: .black.opacity(0.10), location: 0.35),
        .init(color: .black.opacity(0.025), location: 0.7),
        .init(color: .clear, location: 1),
      ],
      startPoint: shadowStart,
      endPoint: shadowEnd
    )
    .frame(
      width: layout.position.isVertical ? layout.shadowExtent : layout.contentFrame.width,
      height: layout.position.isVertical ? layout.contentFrame.height : layout.shadowExtent
    )
    .offset(
      x: layout.position == .left ? layout.contentFrame.maxX : 0,
      y: layout.position == .top ? layout.contentFrame.maxY : 0
    )
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var shadowStart: UnitPoint {
    switch layout.position {
    case .top: .top
    case .bottom: .bottom
    case .left: .leading
    case .right: .trailing
    }
  }

  private var shadowEnd: UnitPoint {
    switch layout.position {
    case .top: .bottom
    case .bottom: .top
    case .left: .trailing
    case .right: .leading
    }
  }
}
