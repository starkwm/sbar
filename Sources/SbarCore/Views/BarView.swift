import SwiftUI

struct BarView: View {
  let configuration: Configuration
  var notch: CGRect?
  var hitRegionsChanged: (([CGRect]) -> Void)?

  var body: some View {
    BarRegionLayout(
      hasCenter: configuration.items.center.contains(where: \.enabled),
      notch: notch.map { $0.offsetBy(dx: -(configuration.theme?.horizontalPadding ?? 10), dy: 0) }
    ) {
      region(configuration.items.left, alignment: .leading)
      region(configuration.items.center, alignment: notch == nil ? .center : .leading)
      region(configuration.items.right, alignment: .trailing)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, configuration.theme?.horizontalPadding ?? 10)
    .coordinateSpace(name: "bar")
    .onPreferenceChange(BarHitRegionsKey.self) { hitRegionsChanged?($0) }
    .background {
      if let color = Color(hex: configuration.theme?.background) {
        color
      } else {
        Rectangle().fill(.ultraThinMaterial)
      }
    }
  }

  private func region(_ items: [Item], alignment: Alignment) -> some View {
    BarRegionView(items: items, theme: configuration.theme, alignment: alignment)
  }
}
