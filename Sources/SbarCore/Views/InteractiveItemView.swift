import SwiftUI

struct InteractiveItemView: View {
  let item: Item
  let defaultStyle: ItemStyle?
  var tracksHitRegion = true

  var body: some View {
    if providers.isVisible(item, displayUUID: barDisplayUUID) {
      content
    }
  }

  @Environment(\.barPosition) private var barPosition
  @Environment(\.barDisplayUUID) private var barDisplayUUID

  @Environment(ProviderRuntime.self) private var providers

  @Environment(ActionRunner.self) private var actions

  @State private var hovering = false
  @State private var showingPopup = false

  private var style: ItemStyle {
    var style = (item.style ?? ItemStyle()).resolved(over: defaultStyle)

    if let tint = providers.presentation(for: item, displayUUID: barDisplayUUID)?.tint {
      style.tint = tint
    }

    return style
  }

  private var itemView: some View {
    BarItemView(
      configuration: item,
      symbolFontSize: style.fontSize ?? 13,
      symbolFontWeight: style.symbolFontWeight,
      tintOverride: hovering && interactive ? style.hoverTint : nil
    )
  }

  private var content: some View {
    Group {
      if item.type == .group {
        let layout = barPosition.stack(spacing: item.itemSpacing ?? 4)
        layout {
          ForEach(visibleChildren) { child in
            AnyView(
              InteractiveItemView(
                item: child,
                defaultStyle: item.childStyle?.resolved(over: defaultStyle) ?? defaultStyle,
                tracksHitRegion: tracksHitRegion
              )
            )
          }
        }
      } else if item.primaryAction != nil || hasPopup || item.type == .pomodoro {
        Button {
          if let action = item.primaryAction {
            actions.run(action)
          } else if item.type == .pomodoro && item.popup == nil {
            actions.run(ItemAction(kind: .pomodoro, value: "toggle"))
          }
          if hasPopup { showingPopup.toggle() }
        } label: {
          itemView
        }
        .buttonStyle(ItemButtonStyle())
      } else {
        itemView
      }
    }
    .modifier(ItemStyleModifier(style: style, hovering: hovering && interactive))
    .modifier(HitRegionModifier(enabled: tracksHitRegion))
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .contextMenu {
      if item.type == .pomodoro {
        Button("Start") { runPomodoro(.start) }.disabled(providers.pomodoroState?.status != .ready)
        Button("Pause") { runPomodoro(.pause) }.disabled(
          providers.pomodoroState?.status != .running
        )
        Button("Resume") { runPomodoro(.resume) }.disabled(
          providers.pomodoroState?.status != .paused
        )
        Button("Skip phase") { runPomodoro(.skip) }
        Button("Reset cycle") { runPomodoro(.reset) }
      }
      if let action = item.secondaryAction {
        Button("Run secondary action") { actions.run(action) }
      }
    }
    .popover(isPresented: $showingPopup, arrowEdge: barPosition.popoverEdge) {
      VStack(alignment: .leading, spacing: 8) {
        if item.type == .agentActivity { AgentActivityPopup(item: item) }
        if let popup = item.popup { Text(popup).textSelection(.enabled) }

        ForEach(visibleChildren) { child in
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
      .environment(\.barPosition, .top)
    }
    .help(
      providers.presentation(for: item, displayUUID: barDisplayUUID)?.accessibilityLabel ?? item.id
    )
  }

  private var visibleChildren: [Item] {
    (item.children ?? []).filter { providers.isVisible($0, displayUUID: barDisplayUUID) }
  }

  private var interactive: Bool {
    item.primaryAction != nil || item.secondaryAction != nil || hasPopup || item.type == .pomodoro
  }

  private var hasPopup: Bool {
    item.popup != nil || item.type == .popup || item.type == .agentActivity
  }

  private func runPomodoro(_ operation: PomodoroOperation) {
    actions.run(ItemAction(kind: .pomodoro, value: operation.rawValue))
  }
}

private struct ItemButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
  }
}
