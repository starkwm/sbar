import SwiftUI

struct BarRegionView: View {
  let items: [Item]
  let theme: Theme?
  let alignment: Alignment
  var style: RegionStyle?

  var body: some View {
    let displayed = items.filter { providers.isVisible($0, displayUUID: barDisplayUUID) }
    GeometryReader { geometry in
      let resolved = (style ?? RegionStyle()).resolved(over: theme?.regionStyle)
      let horizontalPadding = min(resolved.horizontalPadding ?? 0, geometry.size.width / 2)
      let verticalPadding = min(resolved.verticalPadding ?? 0, geometry.size.height / 2)
      let contentWidth = max(0, geometry.size.width - horizontalPadding * 2)
      let contentHeight = max(0, geometry.size.height - verticalPadding * 2)
      let shape = RoundedRectangle(cornerRadius: resolved.cornerRadius ?? 0)
      let spacing = resolved.itemSpacing ?? theme?.itemSpacing ?? 10
      let visible = OverflowSelection.visibleItemIDs(
        items: displayed,
        lengths: lengths,
        available: barPosition.isVertical ? contentHeight : contentWidth,
        spacing: spacing,
        defaultStyle: theme?.itemStyle,
        isVertical: barPosition.isVertical
      )

      if !displayed.isEmpty {
        let layout = barPosition.stack(spacing: spacing)
        layout {
          ForEach(displayed.filter { visible.contains($0.id) }) { item in
            InteractiveItemView(item: item, defaultStyle: theme?.itemStyle)
              .lineLimit(1)
              .minimumScaleFactor(barPosition.isVertical ? 1 : 0.8)
          }

          if visible.count < displayed.count {
            Button {
              showingOverflow.toggle()
            } label: {
              Image(systemName: "ellipsis")
            }
            .buttonStyle(.plain)
            .frame(
              width: barPosition.isVertical ? nil : 28,
              height: barPosition.isVertical ? 28 : nil
            )
            .modifier(HitRegionModifier())
            .accessibilityLabel("More bar items")
            .popover(isPresented: $showingOverflow, arrowEdge: barPosition.popoverEdge) {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(displayed.filter { !visible.contains($0.id) }) { item in
                  InteractiveItemView(item: item, defaultStyle: theme?.itemStyle)
                }
              }
              .padding()
              .frame(maxWidth: 480)
              .focusEffectDisabled()
              .environment(\.barPosition, .top)
            }
          }
        }
        .frame(
          width: barPosition.isVertical ? contentWidth : nil,
          height: barPosition.isVertical ? nil : contentHeight
        )
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background {
          shape
            .fill(Color(hex: resolved.background) ?? .clear)
        }
        .clipShape(shape)
        .overlay {
          shape
            .strokeBorder(
              Color(hex: resolved.borderColor) ?? .clear,
              lineWidth: resolved.borderWidth ?? 0
            )
            .allowsHitTesting(false)
        }
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
        .background {
          let layout = barPosition.stack(spacing: 0)
          layout {
            ForEach(displayed) { item in
              InteractiveItemView(
                item: item,
                defaultStyle: theme?.itemStyle,
                tracksHitRegion: false
              )
              .lineLimit(1)
              .frame(width: barPosition.isVertical ? contentWidth : nil)
              .fixedSize(horizontal: !barPosition.isVertical, vertical: true)
              .background(
                GeometryReader { measurement in
                  Color.clear.preference(
                    key: ItemLengthsKey.self,
                    value: [
                      item.id: barPosition.isVertical
                        ? measurement.size.height : measurement.size.width
                    ]
                  )
                }
              )
            }
          }
          .hidden().allowsHitTesting(false).accessibilityHidden(true)
        }
      }
    }
    .onPreferenceChange(ItemLengthsKey.self) { lengths = $0 }
    .clipped()
  }

  @Environment(\.barPosition) private var barPosition
  @Environment(\.barDisplayUUID) private var barDisplayUUID
  @Environment(ProviderRuntime.self) private var providers

  @State private var lengths: [String: CGFloat] = [:]
  @State private var showingOverflow = false
}

struct OverflowSelection {
  static func visibleItemIDs(
    items: [Item],
    lengths: [String: CGFloat],
    available: CGFloat,
    spacing: CGFloat,
    defaultStyle: ItemStyle? = nil,
    isVertical: Bool = false
  ) -> Set<String> {
    var selected = items
    let flexible: Set<ItemType> = [.text, .frontApplication, .media, .command, .plugin]

    func length() -> CGFloat {
      selected.reduce(0) { total, item in
        if isVertical { return total + (lengths[item.id] ?? 28) }

        let style = (item.style ?? ItemStyle()).resolved(over: defaultStyle)

        if let width = style.width { return total + width }

        let measured = (lengths[item.id] ?? 40) * (flexible.contains(item.type) ? 0.8 : 1)

        return total + max(style.minWidth ?? 0, measured)
      }
        + CGFloat(max(0, selected.count - 1)) * spacing
    }

    if length() <= available { return Set(selected.map(\.id)) }

    for item in items.enumerated().sorted(by: {
      $0.element.priority == $1.element.priority
        ? $0.offset > $1.offset : $0.element.priority < $1.element.priority
    }) {
      selected.removeAll { $0.id == item.element.id }

      if length() + (selected.isEmpty ? 0 : spacing) + 28 <= available { break }
    }

    return Set(selected.map(\.id))
  }
}

private struct ItemLengthsKey: PreferenceKey {
  static let defaultValue: [String: CGFloat] = [:]

  static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
    value.merge(nextValue()) { _, new in new }
  }
}
