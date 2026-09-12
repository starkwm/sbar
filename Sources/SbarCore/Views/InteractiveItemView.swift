import SwiftUI

struct InteractiveItemView: View {
  let item: Item
  let defaultStyle: ItemStyle?
  var tracksHitRegion = true

  var body: some View {
    if providers.isVisible(item, displayUUID: barDisplayUUID) {
      decoratedContent
    }
  }

  @Environment(\.barDisplayUUID) private var barDisplayUUID

  @Environment(ProviderRuntime.self) private var providers

  private var resolvedStyle: ItemStyle {
    var style = (item.style ?? ItemStyle()).resolved(over: defaultStyle)
    if let tint = providers.presentation(for: item, displayUUID: barDisplayUUID)?.tint {
      style.tint = tint
    }
    return style
  }

  private var decoratedContent: some View {
    Group {
      if item.type == .group {
        HStack(spacing: 4) {
          ForEach(displayedChildren) { child in
            AnyView(
              InteractiveItemView(
                item: child,
                defaultStyle: defaultStyle,
                tracksHitRegion: tracksHitRegion
              )
            )
          }
        }
      } else if item.primaryAction != nil || item.popup != nil || item.type == .popup {
        Button {
          if let action = item.primaryAction { actions.run(action) }
          if item.popup != nil || item.type == .popup { showingPopup.toggle() }
        } label: {
          BarItemView(
            configuration: item,
            symbolFontSize: resolvedStyle.fontSize ?? 13,
            symbolFontWeight: resolvedStyle.symbolFontWeight,
            tintOverride: hovering && interactive ? resolvedStyle.hoverTint : nil
          )
        }
        .buttonStyle(.plain)
      } else {
        BarItemView(
          configuration: item,
          symbolFontSize: resolvedStyle.fontSize ?? 13,
          symbolFontWeight: resolvedStyle.symbolFontWeight,
          tintOverride: hovering && interactive ? resolvedStyle.hoverTint : nil
        )
      }
    }
    .modifier(ItemStyleModifier(style: resolvedStyle, hovering: hovering && interactive))
    .modifier(HitRegionModifier(enabled: tracksHitRegion))
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .contextMenu {
      if let action = item.secondaryAction {
        Button("Run secondary action") { actions.run(action) }
      }
    }
    .popover(isPresented: $showingPopup) {
      VStack(alignment: .leading, spacing: 8) {
        if let popup = item.popup { Text(popup).textSelection(.enabled) }

        ForEach(displayedChildren) { child in
          AnyView(
            InteractiveItemView(
              item: child,
              defaultStyle: defaultStyle,
              tracksHitRegion: tracksHitRegion
            )
          )
        }

        if let error = actions.errorMessage { Text(error).foregroundStyle(.red) }
      }
      .padding()
      .frame(minWidth: 120, maxWidth: 480)
      .focusEffectDisabled()
    }
    .help(item.label ?? item.id)
  }

  @Environment(ActionRunner.self) private var actions

  @State private var hovering = false
  @State private var showingPopup = false

  private var displayedChildren: [Item] {
    (item.children ?? []).filter { providers.isVisible($0, displayUUID: barDisplayUUID) }
  }

  private var interactive: Bool {
    item.primaryAction != nil || item.secondaryAction != nil || item.popup != nil
      || item.type == .popup
  }
}
