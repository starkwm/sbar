import SwiftUI

struct OverflowSelection {
    static func visible(items: [ItemConfiguration], widths: [String: CGFloat], available: CGFloat, spacing: CGFloat) -> Set<String> {
        var selected = items
        let flexible: Set<ItemType> = [.text, .frontApplication, .media, .command, .plugin]
        func width() -> CGFloat { selected.reduce(0) { $0 + (widths[$1.id] ?? 40) * (flexible.contains($1.type) ? 0.8 : 1) } + CGFloat(max(0, selected.count - 1)) * spacing }
        if width() <= available { return Set(selected.map(\.id)) }
        for item in items.enumerated().sorted(by: { $0.element.priority == $1.element.priority ? $0.offset > $1.offset : $0.element.priority < $1.element.priority }) {
            selected.removeAll { $0.id == item.element.id }
            if width() + (selected.isEmpty ? 0 : spacing) + 28 <= available { break }
        }
        return Set(selected.map(\.id))
    }
}

struct BarRegionView: View {
    let items: [ItemConfiguration]
    let theme: BarTheme?
    let alignment: Alignment

    var body: some View {
        GeometryReader { geometry in
            let enabled = items.filter(\.enabled)
            let spacing = theme?.itemSpacing ?? 10
            let visible = OverflowSelection.visible(items: enabled, widths: widths, available: geometry.size.width, spacing: spacing)
            HStack(spacing: spacing) {
                ForEach(enabled.filter { visible.contains($0.id) }) { item in
                    InteractiveItemView(item: item, theme: theme?.itemStyle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if visible.count < enabled.count {
                    Button { showingOverflow.toggle() } label: { Image(systemName: "ellipsis") }
                        .buttonStyle(.plain)
                        .frame(width: 28)
                        .modifier(BarHitRegion())
                        .accessibilityLabel("More bar items")
                        .popover(isPresented: $showingOverflow) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(enabled.filter { !visible.contains($0.id) }) { item in
                                    InteractiveItemView(item: item, theme: theme?.itemStyle)
                                }
                            }.padding().frame(maxWidth: 480)
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
        }
        .background {
            HStack(spacing: 0) {
                ForEach(items.filter(\.enabled)) { item in
                    InteractiveItemView(item: item, theme: theme?.itemStyle, tracksHitRegion: false)
                        .fixedSize()
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: ItemWidths.self, value: [item.id: geometry.size.width])
                        })
                }
            }
            .hidden().allowsHitTesting(false).accessibilityHidden(true)
        }
        .onPreferenceChange(ItemWidths.self) { widths = $0 }
        .clipped()
    }

    @State private var widths: [String: CGFloat] = [:]
    @State private var showingOverflow = false
}

private struct ItemWidths: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}
