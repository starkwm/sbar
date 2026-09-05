import Foundation

struct Configuration: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey { case schemaVersion, bar, items, theme }

  static let currentSchemaVersion = 1
  static let `default` = Configuration(
    schemaVersion: currentSchemaVersion,
    bar: .init(),
    items: .init(
      left: [.init(id: "app", type: .frontApplication)],
      right: [
        .init(id: "divider", type: .divider), .init(id: "clock", type: .clock, format: "HH:mm"),
      ]
    )
  )

  var schemaVersion: Int
  var bar: BarSettings
  var items: ItemSections
  var theme: Theme? = nil

  init(
    schemaVersion: Int = Self.currentSchemaVersion,
    bar: BarSettings,
    items: ItemSections,
    theme: Theme? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.bar = bar
    self.items = items
    self.theme = theme
  }

  func validate() throws {
    guard schemaVersion == Self.currentSchemaVersion else {
      throw ConfigurationError.unsupportedSchemaVersion(schemaVersion)
    }

    guard (20...96).contains(bar.height) else {
      throw ConfigurationError.invalidBarHeight(bar.height)
    }

    if bar.displays == .selected && (bar.displayIDs ?? []).isEmpty {
      throw ConfigurationError.invalidValue(
        path: "bar.displayIDs",
        reason: "Select at least one display ID."
      )
    }

    for (edge, value) in [
      ("top", bar.margin?.top), ("bottom", bar.margin?.bottom),
      ("left", bar.margin?.left), ("right", bar.margin?.right),
    ] {
      try ItemStyle.validateNumber(value, range: 0...4096, path: "bar.margin.\(edge)")
    }
    try theme?.validate()

    var identifiers = Set<String>()

    func validateItems(_ entries: [Item], path: String, depth: Int = 0) throws {
      guard depth <= 8 else {
        throw ConfigurationError.invalidValue(
          path: path,
          reason: "Groups may nest at most eight levels."
        )
      }

      for (index, item) in entries.enumerated() {
        let location = "\(path)[\(index)]"

        if item.refresh?.mode == .interval && item.refresh?.seconds == nil {
          throw ConfigurationError.invalidValue(
            path: "\(location).refresh.seconds",
            reason: "An interval needs a duration."
          )
        }
        try ItemStyle.validateNumber(
          item.refresh?.seconds,
          range: 1...86400,
          path: "\(location).refresh.seconds"
        )

        if item.type == .plugin && item.plugin == nil {
          throw ConfigurationError.invalidValue(
            path: "\(location).plugin",
            reason: "Plugin settings are required."
          )
        }
        if let plugin = item.plugin, plugin.executable.isEmpty {
          throw ConfigurationError.invalidValue(
            path: "\(location).plugin.executable",
            reason: "Executable must not be empty."
          )
        }

        if item.type == .command && item.command == nil {
          throw ConfigurationError.invalidValue(
            path: "\(location).command",
            reason: "Command settings are required."
          )
        }
        try ItemStyle.validateNumber(
          item.command?.timeout,
          range: 0.1...60,
          path: "\(location).command.timeout"
        )

        try item.style?.validate(path: "\(location).style")

        guard !item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          throw ConfigurationError.invalidItemIdentifier(
            path: "\(location).id",
            reason: "Must not be empty."
          )
        }

        guard identifiers.insert(item.id).inserted else {
          throw ConfigurationError.invalidItemIdentifier(
            path: "\(location).id",
            reason: "Duplicate ID '\(item.id)'."
          )
        }

        if let children = item.children {
          try validateItems(children, path: "\(location).children", depth: depth + 1)
        }
      }
    }

    try validateItems(items.left, path: "items.left")
    try validateItems(items.center, path: "items.center")
    try validateItems(items.right, path: "items.right")
  }
}

struct BarSettings: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey {
    case position, height, margin, displays, displayIDs, windowLevel, mousePassThrough
  }

  var position: BarPosition = .top
  var height: Double = 32
  var margin: BarMargin?

  var displays: DisplaySelection = .all
  var displayIDs: [UInt32]?

  var windowLevel: BarWindowLevel?
  var mousePassThrough: Bool?

  init(
    position: BarPosition = .top,
    height: Double = 32,
    margin: BarMargin? = nil,
    displays: DisplaySelection = .all,
    displayIDs: [UInt32]? = nil,
    windowLevel: BarWindowLevel? = nil,
    mousePassThrough: Bool? = nil
  ) {
    self.position = position
    self.height = height
    self.margin = margin

    self.displays = displays
    self.displayIDs = displayIDs

    self.windowLevel = windowLevel
    self.mousePassThrough = mousePassThrough
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    position = try container.decodeIfPresent(BarPosition.self, forKey: .position) ?? .top
    height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 32
    margin = try container.decodeIfPresent(BarMargin.self, forKey: .margin)

    displays = try container.decodeIfPresent(DisplaySelection.self, forKey: .displays) ?? .all
    displayIDs = try container.decodeIfPresent([UInt32].self, forKey: .displayIDs)

    windowLevel = try container.decodeIfPresent(BarWindowLevel.self, forKey: .windowLevel)
    mousePassThrough = try container.decodeIfPresent(Bool.self, forKey: .mousePassThrough)
  }
}

struct BarMargin: Codable, Equatable, Sendable {
  var top: Double?
  var bottom: Double?
  var left: Double?
  var right: Double?
}

struct ItemSections: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey { case left, center, right }

  var left: [Item] = []
  var center: [Item] = []
  var right: [Item] = []

  var active: [Item] { (left + center + right).flatMap(\.active) }

  var all: [Item] { (left + center + right).flatMap(\.flattened) }

  init(
    left: [Item] = [],
    center: [Item] = [],
    right: [Item] = []
  ) {
    self.left = left
    self.center = center
    self.right = right
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    left = try container.decodeIfPresent([Item].self, forKey: .left) ?? []
    center = try container.decodeIfPresent([Item].self, forKey: .center) ?? []
    right = try container.decodeIfPresent([Item].self, forKey: .right) ?? []
  }
}

struct Item: Codable, Equatable, Identifiable, Sendable {
  private enum CodingKeys: String, CodingKey {
    case enabled, format, id, label, priority, style, symbol, type, primaryAction, secondaryAction,
      popup, command, children, plugin, refresh
  }

  var id: String
  var type: ItemType
  var enabled: Bool = true

  var label: String?
  var symbol: String?
  var format: String?
  var priority: Int = 0
  var style: ItemStyle?

  var primaryAction: ItemAction?
  var secondaryAction: ItemAction?
  var popup: String?

  var command: ShellCommand?
  var children: [Item]?
  var plugin: Plugin?
  var refresh: RefreshPolicy?

  var active: [Item] { enabled ? [self] + (children ?? []).flatMap(\.active) : [] }

  var flattened: [Item] { [self] + (children ?? []).flatMap(\.flattened) }

  init(
    id: String,
    type: ItemType,
    enabled: Bool = true,
    label: String? = nil,
    symbol: String? = nil,
    format: String? = nil,
    priority: Int = 0,
    style: ItemStyle? = nil,
    primaryAction: ItemAction? = nil,
    secondaryAction: ItemAction? = nil,
    popup: String? = nil,
    command: ShellCommand? = nil,
    children: [Item]? = nil,
    plugin: Plugin? = nil,
    refresh: RefreshPolicy? = nil
  ) {
    self.id = id
    self.type = type
    self.enabled = enabled

    self.label = label
    self.symbol = symbol
    self.format = format
    self.priority = priority
    self.style = style

    self.primaryAction = primaryAction
    self.secondaryAction = secondaryAction
    self.popup = popup

    self.command = command
    self.children = children
    self.plugin = plugin
    self.refresh = refresh
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    type = try container.decode(ItemType.self, forKey: .type)
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true

    label = try container.decodeIfPresent(String.self, forKey: .label)
    symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
    format = try container.decodeIfPresent(String.self, forKey: .format)
    priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    style = try container.decodeIfPresent(ItemStyle.self, forKey: .style)

    primaryAction = try container.decodeIfPresent(ItemAction.self, forKey: .primaryAction)
    secondaryAction = try container.decodeIfPresent(ItemAction.self, forKey: .secondaryAction)
    popup = try container.decodeIfPresent(String.self, forKey: .popup)

    command = try container.decodeIfPresent(ShellCommand.self, forKey: .command)
    children = try container.decodeIfPresent([Item].self, forKey: .children)
    plugin = try container.decodeIfPresent(Plugin.self, forKey: .plugin)
    refresh = try container.decodeIfPresent(RefreshPolicy.self, forKey: .refresh)
  }
}

enum BarPosition: String, Codable, Sendable { case top, bottom }

enum DisplaySelection: String, Codable, Sendable { case main, all, selected }

enum BarWindowLevel: String, Codable, CaseIterable, Sendable {
  case floating, statusBar, screenSaver
}

enum ItemType: String, CaseIterable, Codable, Sendable {
  case clock, date, divider, frontApplication, spacer, text, battery, volume, network, wifi, cpu,
    memory, disk, throughput, media, command, group, popup, plugin, aerospace, yabai, spaces
}

enum ConfigurationError: Error, Equatable, LocalizedError {
  case invalidValue(path: String, reason: String)
  case invalidItemIdentifier(path: String, reason: String)
  case invalidBarHeight(Double)
  case unsupportedSchemaVersion(Int)

  var errorDescription: String? {
    switch self {
    case .invalidValue(let path, let reason): "\(path): \(reason)"
    case .invalidItemIdentifier(let path, let reason): "\(path): \(reason)"
    case .invalidBarHeight(let height):
      "bar.height: \(height) is outside the supported range of 20...96."
    case .unsupportedSchemaVersion(let version): "schemaVersion: \(version) is not supported."
    }
  }
}
