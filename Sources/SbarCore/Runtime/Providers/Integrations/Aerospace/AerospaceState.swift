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
      return WorkspaceText().apply(
        to: WidgetPresentation(
          text: unavailable ?? "Aerospace unavailable",
          symbol: settings.showSymbol == false
            ? nil
            : item.symbol ?? settings.symbols?.resolve(settings.symbols?.unavailable)
              ?? "questionmark",
          tint: settings.tints?.unavailable,
          accessibilityLabel: unavailable ?? "Aerospace unavailable"
        ),
        for: item
      )
    }

    let label = current.name
    func entry(_ row: AerospaceWorkspace) -> WorkspaceText.Entry {
      WorkspaceText.Entry(
        name: row.name,
        index: rows.firstIndex(where: { $0.name == row.name }).map { $0 + 1 },
        identifier: row.name,
        active: row.name == current.name,
        focused: row.focused,
        visible: row.visible,
        tint: row.focused
          ? settings.tints?.focused
          : row.visible ? settings.tints?.visible : settings.tints?.inactive,
        emphasized: row.focused
      )
    }

    return WorkspaceText(current: entry(current), entries: rows.map(entry)).apply(
      to: WidgetPresentation(
        text: label,
        symbol: settings.showSymbol == false
          ? nil
          : item.symbol ?? settings.symbols?.resolve(settings.symbols?.available)
            ?? "rectangle.3.group",
        tint: current.focused ? settings.tints?.focused : settings.tints?.visible,
        accessibilityLabel: "Workspace \(label)\(current.focused ? ", focused" : ", visible"). "
          + rows.map { "\($0.name)\($0.focused ? " focused" : $0.visible ? " visible" : "")" }
          .joined(
            separator: ", "
          )
      ),
      for: item
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
