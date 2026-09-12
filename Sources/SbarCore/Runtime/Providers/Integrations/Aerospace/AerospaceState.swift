import Foundation

struct AerospaceState: Equatable, Sendable {
  static func parse(_ data: Data, displays: [Int: String]) throws -> Self {
    let rows = try JSONDecoder().decode([AerospaceWorkspace].self, from: data)
    var names = Set<String>()
    var visibleMonitors = Set<Int>()
    guard !rows.isEmpty, rows.filter(\.focused).count == 1,
      rows.allSatisfy({
        !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && names.insert($0.name).inserted && $0.monitor > 0 && (!$0.focused || $0.visible)
          && (!$0.visible || visibleMonitors.insert($0.monitor).inserted)
      })
    else { return Self() }
    return Self(workspaces: rows, displays: displays, unavailable: nil)
  }

  var workspaces: [AerospaceWorkspace] = []
  var displays: [Int: String] = [:]
  var unavailable: String? = "Aerospace unavailable"

  var text: String {
    workspaces.first(where: \.focused)?.name ?? unavailable ?? "Aerospace unavailable"
  }

  func presentation(for item: Item, displayUUID: String?) -> WidgetPresentation {
    let settings = item.aerospace ?? AerospaceConfiguration()
    let rows =
      settings.scope == .display
      ? workspaces.filter {
        displays[$0.monitor]?.lowercased() == displayUUID?.lowercased() && displayUUID != nil
      }
      : workspaces
    let current = rows.first { settings.scope == .display ? $0.visible : $0.focused }
    guard unavailable == nil, let current else {
      return WidgetPresentation(
        text: settings.showValue == false ? "" : unavailable ?? "Aerospace unavailable",
        symbol: settings.showSymbol == false
          ? nil
          : item.symbol ?? settings.symbols?.resolve(settings.symbols?.unavailable)
            ?? "questionmark",
        tint: settings.tints?.unavailable,
        accessibilityLabel: unavailable ?? "Aerospace unavailable"
      )
    }
    let label = settings.labels?[current.name] ?? current.name
    let segments =
      settings.format == .list && settings.showValue != false
      ? rows.map { row in
        WidgetSegment(
          text: settings.labels?[row.name] ?? row.name,
          symbol: nil,
          tint: row.focused
            ? settings.tints?.focused
            : row.visible ? settings.tints?.visible : settings.tints?.inactive,
          emphasized: row.focused
        )
      } : []
    return WidgetPresentation(
      text: settings.showValue == false ? "" : label,
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?.resolve(settings.symbols?.available)
          ?? "rectangle.3.group",
      tint: settings.format == .list
        ? nil : current.focused ? settings.tints?.focused : settings.tints?.visible,
      segments: segments,
      accessibilityLabel: "Workspace \(label)\(current.focused ? ", focused" : ", visible"). "
        + rows.map { "\($0.name)\($0.focused ? " focused" : $0.visible ? " visible" : "")" }.joined(
          separator: ", "
        ),
      tooltipValues: [
        "workspace": label,
        "workspaces": rows.map { settings.labels?[$0.name] ?? $0.name }.joined(separator: ", "),
        "count": String(rows.count),
      ]
    )
  }
}

struct AerospaceWorkspace: Decodable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey {
    case name = "workspace"
    case focused = "workspace-is-focused"
    case visible = "workspace-is-visible"
    case monitor = "monitor-appkit-nsscreen-screens-id"
  }

  var name: String
  var focused: Bool
  var visible: Bool
  var monitor: Int
}
