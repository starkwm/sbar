import Foundation

struct SpacesState: Equatable, Sendable {
  static func identifier(_ value: Any?) -> UInt64? {
    guard let number = value as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID(),
      let id = UInt64(number.stringValue), id > 0
    else { return nil }
    return id
  }

  static func parse(displays: [[String: Any]], activeSpaceID: UInt64) -> Self {
    let parsed = displays.enumerated().map { index, display in
      var seen = Set<UInt64>()
      let spaces = (display["Spaces"] as? [[String: Any]] ?? []).compactMap {
        value -> SpaceEntry? in
        guard let id = identifier(value["ManagedSpaceID"]), seen.insert(id).inserted else {
          return nil
        }
        return SpaceEntry(id: id, fullscreen: (value["type"] as? NSNumber)?.intValue == 4)
      }
      let current = display["Current Space"] as? [String: Any]
      return SpaceDisplay(
        identifier: (display["Display Identifier"] as? String)?.lowercased() ?? "unknown-\(index)",
        spaces: spaces,
        activeID: identifier(current?["ManagedSpaceID"])
          ?? ((display["Display Identifier"] as? String)?.lowercased() == "main"
            && activeSpaceID > 0 ? activeSpaceID : nil)
      )
    }
    return Self(displays: parsed, focusedID: activeSpaceID)
  }

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
    let label = index.map { String($0 + 1) } ?? "Fullscreen"
    func entry(_ space: SpaceEntry, index: Int?) -> WorkspaceText.Entry {
      WorkspaceText.Entry(
        name: index.map { String($0 + 1) } ?? "Fullscreen",
        index: index.map { $0 + 1 },
        identifier: String(space.id),
        active: space.id == active,
        focused: space.id == focusedID,
        visible: displays.contains { $0.activeID == space.id },
        fullscreen: space.fullscreen,
        tint: space.id == active ? settings.tints?.active : settings.tints?.inactive,
        emphasized: space.id == active
      )
    }
    let workspaceText = WorkspaceText(
      current: entry(activeEntry, index: index),
      entries: visible.enumerated().map { entry($0.element, index: $0.offset) }
    )
    let accessible =
      index.map { "Space \(label), \($0 + 1) of \(visible.count)" }
      ?? (activeEntry.fullscreen ? "Fullscreen Space active" : "Spaces unavailable")
    return workspaceText.apply(
      to: WidgetPresentation(
        text: label,
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
