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
      return WidgetPresentation(
        text: settings.showValue == false ? "" : "Spaces unavailable",
        symbol: settings.showSymbol == false
          ? nil
          : item.symbol ?? settings.symbols?.resolve(settings.symbols?.unavailable)
            ?? "questionmark",
        tint: settings.tints?.unavailable,
        accessibilityLabel: "Spaces unavailable"
      )
    }
    let visible = entries.filter { settings.includeFullscreen != false || !$0.fullscreen }
    let index = visible.firstIndex { $0.id == active }
    let label = index.map { settings.labels?[String($0 + 1)] ?? String($0 + 1) } ?? "Fullscreen"
    let value =
      settings.format == .currentTotal && index != nil ? "\(label) / \(visible.count)" : label
    let segments =
      settings.format == .list && settings.showValue != false
      ? visible.enumerated().map { offset, entry in
        WidgetSegment(
          text: settings.labels?[String(offset + 1)] ?? String(offset + 1),
          symbol: nil,
          tint: entry.id == active ? settings.tints?.active : settings.tints?.inactive,
          emphasized: entry.id == active
        )
      } : []
    let accessible =
      index.map { "Space \(label), \($0 + 1) of \(visible.count)" }
      ?? (activeEntry.fullscreen ? "Fullscreen Space active" : "Spaces unavailable")
    return WidgetPresentation(
      text: settings.showValue == false ? "" : value,
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?.resolve(settings.symbols?.available)
          ?? "rectangle.3.group",
      tint: settings.format == .list ? nil : settings.tints?.active,
      segments: segments,
      accessibilityLabel: segments.isEmpty
        ? accessible
        : "Spaces \(segments.map(\.text).joined(separator: ", ")). \(accessible)"
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
