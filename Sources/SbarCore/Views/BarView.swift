import SwiftUI

struct BarView: View {
  let configuration: Configuration
  var notch: CGRect?
  var hitRegionsChanged: (([CGRect]) -> Void)?

  var body: some View {
    BarRegionLayout(
      hasCenter: configuration.items.center.contains {
        providers.isVisible($0, displayUUID: barDisplayUUID)
      },
      notch: notch.map { $0.offsetBy(dx: -(configuration.theme?.horizontalPadding ?? 10), dy: 0) }
    ) {
      region(
        configuration.items.left,
        style: configuration.theme?.regions?.left,
        alignment: .leading
      )
      region(
        configuration.items.center,
        style: configuration.theme?.regions?.center,
        alignment: notch == nil ? .center : .leading
      )
      region(
        configuration.items.right,
        style: configuration.theme?.regions?.right,
        alignment: .trailing
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, configuration.theme?.horizontalPadding ?? 10)
    .padding(
      .vertical,
      min(configuration.theme?.verticalPadding ?? 0, configuration.bar.height / 2)
    )
    .coordinateSpace(name: "bar")
    .onPreferenceChange(HitRegionsKey.self) { hitRegionsChanged?($0) }
    .background {
      if let color = Color(hex: configuration.theme?.background) {
        color
      } else {
        BarBackgroundView()
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: configuration.theme?.cornerRadius ?? 0))
  }

  @Environment(\.barDisplayUUID) private var barDisplayUUID
  @Environment(ProviderRuntime.self) private var providers

  private func region(_ items: [Item], style: RegionStyle?, alignment: Alignment) -> some View {
    BarRegionView(items: items, theme: configuration.theme, alignment: alignment, style: style)
  }
}
