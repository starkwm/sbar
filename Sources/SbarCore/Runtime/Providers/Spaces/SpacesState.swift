import Foundation

struct SpacesState: Equatable, Sendable {
  var displays: [SpaceDisplay] = []
  var focusedID: UInt64 = 0

  var complete: Bool {
    displays.contains { $0.spaces.contains { $0.id == focusedID } }
      && displays.allSatisfy { display in
        display.activeID.map { id in display.spaces.contains { $0.id == id } }
          ?? false
      }
  }

  var text: String { presentation(for: Item(id: "spaces", type: .spaces)).text }

  func isFullscreen(displayUUID: String?) -> Bool {
    let display =
      displays.first { $0.identifier == displayUUID?.lowercased() }
      ?? displays.first { $0.identifier == "main" }
    guard let display, let activeID = display.activeID else { return false }

    return display.spaces.first { $0.id == activeID }?.fullscreen ?? false
  }

  func presentation(for item: Item, displayUUID: String? = nil) -> WidgetPresentation {
    let settings = item.spaces ?? SpacesConfiguration()
    let entries: [SpaceEntry]
    let active: UInt64?

    if settings.scope == .display {
      let display =
        displays.first { $0.identifier == displayUUID?.lowercased() }
        ?? displays.first { $0.identifier == "main" }
      entries = display?.spaces ?? []
      active = display?.activeID
    } else {
      var seen = Set<UInt64>()
      entries = displays.flatMap(\.spaces).filter { seen.insert($0.id).inserted }
      active = focusedID
    }

    guard let active, let activeEntry = entries.first(where: { $0.id == active }) else {
      return WorkspaceText().apply(
        to: WidgetPresentation(
          text: "Spaces unavailable",
          symbol: settings.showSymbol == false
            ? nil
            : item.symbol ?? settings.symbols?.resolve(settings.symbols?.unavailable)
              ?? "questionmark",
          tint: settings.tints?.unavailable,
          accessibilityLabel: "Spaces unavailable"
        ),
        for: item
      )
    }

    let visible = entries.filter { settings.includeFullscreen != false || !$0.fullscreen }
    let index = visible.firstIndex { $0.id == active }

    func name(at index: Int?) -> SpaceName? {
      guard let index, let names = settings.names, names.indices.contains(index) else { return nil }

      return names[index]
    }

    func entry(_ space: SpaceEntry, index: Int?) -> WorkspaceText.Entry {
      var label = index.map { String($0 + 1) } ?? "Fullscreen"
      var symbol: ItemSymbol?

      switch name(at: index) {
      case .text(let text) where !text.isEmpty:
        label = text
      case .symbol(let value):
        symbol = value
      default:
        break
      }

      return WorkspaceText.Entry(
        name: label,
        index: index.map { $0 + 1 },
        identifier: String(space.id),
        active: space.id == active,
        focused: space.id == focusedID,
        visible: displays.contains { $0.activeID == space.id },
        fullscreen: space.fullscreen,
        tint: space.id == active ? settings.tints?.active : settings.tints?.inactive,
        emphasized: space.id == active,
        nameSymbol: symbol
      )
    }

    let current = entry(activeEntry, index: index)
    let text = WorkspaceText(
      current: current,
      entries: visible.enumerated().map { entry($0.element, index: $0.offset) }
    )
    let accessible =
      index.map { "Space \(current.name), \($0 + 1) of \(visible.count)" }
      ?? (activeEntry.fullscreen ? "Fullscreen Space active" : "Spaces unavailable")

    return text.apply(
      to: WidgetPresentation(
        text: current.name,
        symbol: settings.showSymbol == false
          ? nil
          : item.symbol ?? settings.symbols?.resolve(settings.symbols?.available)
            ?? "rectangle.3.group",
        tint: settings.tints?.active,
        accessibilityLabel: accessible
      ),
      for: item
    )
  }
}

struct SpaceDisplay: Equatable, Sendable {
  var identifier: String
  var spaces: [SpaceEntry]
  var activeID: UInt64?
}

struct SpaceEntry: Equatable, Sendable {
  var id: UInt64
  var fullscreen: Bool = false
}
