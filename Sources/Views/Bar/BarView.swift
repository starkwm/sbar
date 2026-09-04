import SwiftUI

struct BarView: View {
    let configuration: BarConfiguration

    var body: some View {
        BarRegionLayout {
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
        HStack(spacing: configuration.theme?.itemSpacing ?? 10) {
            ForEach(items.filter(\.enabled)) { item in
                BarItemView(configuration: item)
                    .modifier(ItemStyleModifier(style: (item.style ?? ItemStyle()).resolved(over: configuration.theme?.itemStyle)))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: alignment)
        .frame(maxHeight: .infinity)
        .clipped()
    }
}
