import SwiftUI

struct InteractiveItemView: View {
  let item: ItemConfiguration
  let defaultStyle: ItemStyle?
  var tracksHitRegion = true

  var body: some View {
    Group {
      if item.type == .group {
        HStack(spacing: 4) {
          ForEach((item.children ?? []).filter(\.enabled)) { child in
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
          BarItemView(configuration: item)
        }
        .buttonStyle(.plain)
      } else {
        BarItemView(configuration: item)
      }
    }
    .modifier(ItemStyleModifier(style: (item.style ?? ItemStyle()).resolved(over: defaultStyle)))
    .modifier(BarHitRegionModifier(enabled: tracksHitRegion))
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .background(hovering && interactive ? Color.primary.opacity(0.08) : .clear)
    .contextMenu {
      if let action = item.secondaryAction {
        Button("Run secondary action") { actions.run(action) }
      }
    }
    .popover(isPresented: $showingPopup) {
      VStack(alignment: .leading, spacing: 8) {
        if let popup = item.popup { Text(popup).textSelection(.enabled) }
        ForEach((item.children ?? []).filter(\.enabled)) { child in
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
    }
    .help(item.label ?? item.id)
  }

  @Environment(ActionRunner.self) private var actions
  @State private var hovering = false
  @State private var showingPopup = false
  private var interactive: Bool {
    item.primaryAction != nil || item.secondaryAction != nil || item.popup != nil
      || item.type == .popup
  }
}
