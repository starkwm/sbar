import SwiftUI

struct BarView: View {
    let configuration: BarConfiguration

    var body: some View {
        ZStack {
            region(configuration.items.left, alignment: .leading)
            region(configuration.items.center, alignment: .center)
            region(configuration.items.right, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
    }

    private func region(_ items: [ItemConfiguration], alignment: Alignment) -> some View {
        HStack(spacing: 10) {
            ForEach(items.filter(\.enabled)) { item in BarItemView(configuration: item) }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }
}
