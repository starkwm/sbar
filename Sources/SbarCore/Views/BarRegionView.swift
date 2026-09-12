import SwiftUI

struct BarRegionView: View {
  let items: [Item]
  let theme: Theme?
  let alignment: Alignment

  var body: some View {
    let displayed = items.filter { providers.isVisible($0, displayUUID: barDisplayUUID) }
    GeometryReader { geometry in
      let spacing = theme?.itemSpacing ?? 10
      let visible = OverflowSelection.visibleItemIDs(
        items: displayed,
        widths: widths,
        available: geometry.size.width,
        spacing: spacing,
        defaultStyle: theme?.itemStyle
      )

      HStack(spacing: spacing) {
        ForEach(displayed.filter { visible.contains($0.id) }) { item in
          InteractiveItemView(item: item, defaultStyle: theme?.itemStyle)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }

        if visible.count < displayed.count {
          Button {
            showingOverflow.toggle()
          } label: {
            Image(systemName: "ellipsis")
          }
          .buttonStyle(.plain)
          .frame(width: 28)
          .modifier(HitRegionModifier())
          .accessibilityLabel("More bar items")
          .popover(isPresented: $showingOverflow) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(displayed.filter { !visible.contains($0.id) }) { item in
                InteractiveItemView(item: item, defaultStyle: theme?.itemStyle)
              }
            }
            .padding()
            .frame(maxWidth: 480)
            .focusEffectDisabled()
          }
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
    }
    .background {
      HStack(spacing: 0) {
        ForEach(displayed) { item in
          InteractiveItemView(item: item, defaultStyle: theme?.itemStyle, tracksHitRegion: false)
            .fixedSize()
            .background(
              GeometryReader { geometry in
                Color.clear.preference(
                  key: ItemWidthsKey.self,
                  value: [item.id: geometry.size.width]
                )
              }
            )
        }
      }
      .hidden().allowsHitTesting(false).accessibilityHidden(true)
    }
    .onPreferenceChange(ItemWidthsKey.self) { widths = $0 }
    .clipped()
  }

  @Environment(\.barDisplayUUID) private var barDisplayUUID
  @Environment(ProviderRuntime.self) private var providers

  @State private var widths: [String: CGFloat] = [:]
  @State private var showingOverflow = false
}

struct OverflowSelection {
  static func visibleItemIDs(
    items: [Item],
    widths: [String: CGFloat],
    available: CGFloat,
    spacing: CGFloat,
    defaultStyle: ItemStyle? = nil
  ) -> Set<String> {
    var selected = items
    let flexible: Set<ItemType> = [.text, .frontApplication, .media, .command, .plugin]

    func width() -> CGFloat {
      selected.reduce(0) { total, item in
        let style = (item.style ?? ItemStyle()).resolved(over: defaultStyle)
        if let width = style.width { return total + width }
        let measured = (widths[item.id] ?? 40) * (flexible.contains(item.type) ? 0.8 : 1)
        return total + max(style.minWidth ?? 0, measured)
      }
        + CGFloat(max(0, selected.count - 1)) * spacing
    }

    if width() <= available { return Set(selected.map(\.id)) }

    for item in items.enumerated().sorted(by: {
      $0.element.priority == $1.element.priority
        ? $0.offset > $1.offset : $0.element.priority < $1.element.priority
    }) {
      selected.removeAll { $0.id == item.element.id }
      if width() + (selected.isEmpty ? 0 : spacing) + 28 <= available { break }
    }

    return Set(selected.map(\.id))
  }
}

private struct ItemWidthsKey: PreferenceKey {
  static let defaultValue: [String: CGFloat] = [:]

  static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
    value.merge(nextValue()) { _, new in new }
  }
}
