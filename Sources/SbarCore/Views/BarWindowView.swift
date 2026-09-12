import SwiftUI

struct BarWindowView: View {
  let configuration: Configuration
  let layout: BarWindowLayout
  var notch: CGRect?
  var hitRegionsChanged: (([CGRect]) -> Void)?

  var body: some View {
    VStack(spacing: 0) {
      if layout.shadowAbove { edgeShadow }
      BarView(configuration: configuration, notch: notch, hitRegionsChanged: hitRegionsChanged)
        .frame(height: layout.contentFrame.height)
      if !layout.shadowAbove { edgeShadow }
    }
  }

  private var edgeShadow: some View {
    LinearGradient(
      stops: [
        .init(color: .black.opacity(0.24), location: 0),
        .init(color: .black.opacity(0.10), location: 0.35),
        .init(color: .black.opacity(0.025), location: 0.7),
        .init(color: .clear, location: 1),
      ],
      startPoint: layout.shadowAbove ? .bottom : .top,
      endPoint: layout.shadowAbove ? .top : .bottom
    )
    .frame(height: layout.shadowExtent)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
