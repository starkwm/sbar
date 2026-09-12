import Foundation

struct YabaiState: Equatable, Sendable {
  static func parse(_ data: Data, displays: [YabaiDisplay]) throws -> Self {
    let rows = try JSONDecoder().decode([YabaiWorkspace].self, from: data)
    var ids = Set<UInt64>()
    var indexes = Set<Int>()
    var displayIndexes = Set<Int>()
    var uuids = Set<String>()
    guard !displays.isEmpty,
      displays.allSatisfy({
        $0.index > 0 && !$0.uuid.isEmpty && displayIndexes.insert($0.index).inserted
          && uuids.insert($0.uuid.lowercased()).inserted
      })
    else { return Self() }
    var visible = Set<Int>()
    guard !rows.isEmpty, rows.filter(\.focused).count == 1,
      rows.allSatisfy({
        $0.id > 0 && $0.index > 0 && ids.insert($0.id).inserted && indexes.insert($0.index).inserted
          && displayIndexes.contains($0.monitor) && (!$0.focused || $0.visible)
          && (!$0.visible || visible.insert($0.monitor).inserted)
      }), visible == displayIndexes
    else { return Self() }
    return Self(
      workspaces: rows.sorted { $0.index < $1.index },
      displays: Dictionary(uniqueKeysWithValues: displays.map { ($0.index, $0.uuid) }),
      unavailable: nil
    )
  }

  var workspaces: [YabaiWorkspace] = []
  var displays: [Int: String] = [:]
  var unavailable: String? = "Yabai unavailable"

  var text: String {
    workspaces.first(where: \.focused)?.name ?? unavailable ?? "Yabai unavailable"
  }

  func presentation(for item: Item, displayUUID: String?) -> WidgetPresentation {
    let settings = item.yabai ?? YabaiConfiguration()
    let rows =
      settings.scope == .display
      ? workspaces.filter {
        displays[$0.monitor]?.lowercased() == displayUUID?.lowercased() && displayUUID != nil
      }
      : workspaces
    let current = rows.first { settings.scope == .display ? $0.visible : $0.focused }
    guard unavailable == nil, let current else {
      return WidgetPresentation(
        text: settings.showValue == false ? "" : unavailable ?? "Yabai unavailable",
        symbol: settings.showSymbol == false
          ? nil
          : item.symbol ?? settings.symbols?.resolve(settings.symbols?.unavailable)
            ?? "questionmark",
        tint: settings.tints?.unavailable,
        accessibilityLabel: unavailable ?? "Yabai unavailable"
      )
    }
    let label =
      settings.includeFullscreen == false && current.fullscreen ? "Fullscreen" : current.name
    let segments =
      settings.format == .list && settings.showValue != false
      ? rows.filter { settings.includeFullscreen != false || !$0.fullscreen }.map { row in
        WidgetSegment(
          text: row.name,
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
        "index": String(current.index),
        "workspaces": rows.filter { settings.includeFullscreen != false || !$0.fullscreen }
          .map(\.name).joined(separator: ", "),
        "count": String(
          rows.filter { settings.includeFullscreen != false || !$0.fullscreen }.count
        ),
      ]
    )
  }
}

struct YabaiWorkspace: Decodable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey {
    case id, index, label
    case focused = "has-focus"
    case visible = "is-visible"
    case monitor = "display"
    case fullscreen = "is-native-fullscreen"
  }

  var id: UInt64
  var index: Int
  var label: String?
  var focused: Bool
  var visible: Bool
  var monitor: Int
  var fullscreen: Bool

  var name: String {
    let value = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return value.isEmpty ? String(index) : value
  }
}

struct YabaiDisplay: Decodable, Equatable, Sendable {
  var uuid: String
  var index: Int
}
