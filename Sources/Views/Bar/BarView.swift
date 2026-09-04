import SwiftUI

struct BarView: View {
    let configuration: BarConfiguration

    var body: some View {
        BarRegionLayout(hasCenter: configuration.items.center.contains(where: \.enabled)) {
            region(configuration.items.left, alignment: .leading)
            region(configuration.items.center, alignment: .center)
            region(configuration.items.right, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, configuration.theme?.horizontalPadding ?? 10)
        .background {
            if let color = Color(hex: configuration.theme?.background) {
                color
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }

    private func region(_ items: [ItemConfiguration], alignment: Alignment) -> some View {
        BarRegionView(items: items, theme: configuration.theme, alignment: alignment)
    }
}
