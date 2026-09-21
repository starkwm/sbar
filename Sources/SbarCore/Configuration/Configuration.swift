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
        .init(id: "divider", type: .divider), .init(id: "clock", type: .datetime, format: "HH:mm"),
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

    try ItemStyle.validateNumber(bar.width, range: 20...96, path: "bar.width")

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

    func validateItem(_ item: Item, path location: String) throws {
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
      if let text = item.text {
        if item.type == .divider || item.type == .spacer || item.type == .group {
          throw ConfigurationError.invalidValue(
            path: "\(location).text",
            reason: "This item has no text."
          )
        }

        _ = try TextTemplate(
          text,
          fields: TextTemplate.fields(for: item.type),
          allowedValues: TextTemplate.allowedValues(for: item.type),
          path: "\(location).text"
        )
      }

      try item.plugin?.validate(path: "\(location).plugin")

      if item.type == .command && item.command == nil {
        throw ConfigurationError.invalidValue(
          path: "\(location).command",
          reason: "Command settings are required."
        )
      }

      try item.command?.validate(path: "\(location).command")

      try item.yabai?.validate(path: "\(location).yabai")
      try item.aerospace?.validate(path: "\(location).aerospace")
      try item.spaces?.validate(path: "\(location).spaces")
      try item.media?.validate(path: "\(location).media")
      try item.throughput?.validate(path: "\(location).throughput")
      try item.disk?.validate(path: "\(location).disk")
      try item.memory?.validate(path: "\(location).memory")
      try item.cpu?.validate(path: "\(location).cpu")
      try item.network?.validate(path: "\(location).network")

      if item.type == .weather && item.weather == nil {
        throw ConfigurationError.invalidValue(
          path: "\(location).weather",
          reason: "Weather coordinates are required."
        )
      }

      try item.weather?.validate(path: "\(location).weather")
      try item.mail?.validate(path: "\(location).mail")
      try item.vpn?.validate(path: "\(location).vpn")
      try item.bluetooth?.validate(path: "\(location).bluetooth")
      try item.audioDevice?.validate(path: "\(location).audioDevice")
      try item.battery?.validate(path: "\(location).battery")
      try item.volume?.validate(path: "\(location).volume")

      if (item.plugin != nil && item.type != .plugin)
        || (item.command != nil && item.type != .command)
        || (item.battery != nil && item.type != .battery)
        || (item.yabai != nil && item.type != .yabai)
        || (item.aerospace != nil && item.type != .aerospace)
        || (item.spaces != nil && item.type != .spaces)
        || (item.media != nil && item.type != .media)
        || (item.throughput != nil && item.type != .throughput)
        || (item.disk != nil && item.type != .disk)
        || (item.memory != nil && item.type != .memory)
        || (item.cpu != nil && item.type != .cpu)
        || (item.network != nil && item.type != .network)
        || (item.weather != nil && item.type != .weather)
        || (item.mail != nil && item.type != .mail)
        || (item.vpn != nil && item.type != .vpn)
        || (item.bluetooth != nil && item.type != .bluetooth)
        || (item.audioDevice != nil && item.type != .audioDevice)
        || (item.volume != nil && item.type != .volume)
        || (item.frontApplication != nil && item.type != .frontApplication)
      {
        throw ConfigurationError.invalidValue(
          path: location,
          reason: "Widget settings must match the item type."
        )
      }
      if item.itemSpacing != nil && item.type != .group {
        throw ConfigurationError.invalidValue(
          path: "\(location).itemSpacing",
          reason: "Only group items support itemSpacing."
        )
      }

      try ItemStyle.validateNumber(
        item.itemSpacing,
        range: 0...96,
        path: "\(location).itemSpacing"
      )

      if item.childStyle != nil && item.type != .group {
        throw ConfigurationError.invalidValue(
          path: "\(location).childStyle",
          reason: "Only group items support childStyle."
        )
      }

      try item.childStyle?.validate(path: "\(location).childStyle")
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

    }

    func validateItems(_ entries: [Item], path: String, depth: Int = 0) throws {
      guard depth <= 8 else {
        throw ConfigurationError.invalidValue(
          path: path,
          reason: "Groups may nest at most eight levels."
        )
      }

      for (index, item) in entries.enumerated() {
        let location = "\(path)[\(index)]"
        try validateItem(item, path: location)

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
    case position, height, width, extendToTopEdge, margin, displays, displayIDs, windowLevel,
      shadow, mousePassThrough
  }

  var position: BarPosition = .top
  var height: Double = 32
  var width: Double = 32
  var extendToTopEdge: Bool = false
  var margin: BarMargin?

  var displays: DisplaySelection = .all
  var displayIDs: [UInt32]?

  var windowLevel: BarWindowLevel?
  var shadow: Bool?
  var mousePassThrough: Bool?

  init(
    position: BarPosition = .top,
    height: Double = 32,
    width: Double = 32,
    extendToTopEdge: Bool = false,
    margin: BarMargin? = nil,
    displays: DisplaySelection = .all,
    displayIDs: [UInt32]? = nil,
    windowLevel: BarWindowLevel? = nil,
    shadow: Bool? = nil,
    mousePassThrough: Bool? = nil
  ) {
    self.position = position
    self.height = height
    self.width = width
    self.extendToTopEdge = extendToTopEdge
    self.margin = margin

    self.displays = displays
    self.displayIDs = displayIDs

    self.windowLevel = windowLevel
    self.shadow = shadow
    self.mousePassThrough = mousePassThrough
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    position = try container.decodeIfPresent(BarPosition.self, forKey: .position) ?? .top
    height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 32
    width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 32
    extendToTopEdge = try container.decodeIfPresent(Bool.self, forKey: .extendToTopEdge) ?? false
    margin = try container.decodeIfPresent(BarMargin.self, forKey: .margin)

    displays = try container.decodeIfPresent(DisplaySelection.self, forKey: .displays) ?? .all
    displayIDs = try container.decodeIfPresent([UInt32].self, forKey: .displayIDs)

    windowLevel = try container.decodeIfPresent(BarWindowLevel.self, forKey: .windowLevel)
    shadow = try container.decodeIfPresent(Bool.self, forKey: .shadow)
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
    case enabled, format, dateStyle, timeStyle, id, text, priority, style, symbol,
      symbolPosition,
      type,
      primaryAction, secondaryAction,
      popup, command, children, itemSpacing, childStyle, plugin, refresh, yabai, aerospace, battery,
      cpu, disk,
      media,
      memory,
      spaces,
      throughput,
      volume,
      network,
      mail, vpn, weather,
      bluetooth,
      audioDevice,
      frontApplication
  }

  var id: String
  var type: ItemType
  var enabled: Bool = true

  var text: String?
  var symbol: ItemSymbol?
  var symbolPosition: ItemSymbolPosition = .left
  var format: String?
  var dateStyle: DateTimeStyle?
  var timeStyle: DateTimeStyle?
  var priority: Int = 0
  var style: ItemStyle?

  var primaryAction: ItemAction?
  var secondaryAction: ItemAction?
  var popup: String?

  var command: ShellCommand?
  var children: [Item]?
  var itemSpacing: Double?
  var childStyle: ItemStyle?
  var plugin: Plugin?
  var frontApplication: FrontApplicationConfiguration?
  var yabai: YabaiConfiguration?
  var aerospace: AerospaceConfiguration?
  var spaces: SpacesConfiguration?
  var media: MediaConfiguration?
  var throughput: ThroughputConfiguration?
  var disk: DiskConfiguration?
  var memory: MemoryConfiguration?
  var cpu: CPUConfiguration?
  var battery: BatteryConfiguration?
  var bluetooth: BluetoothConfiguration?
  var audioDevice: AudioDeviceConfiguration?
  var weather: WeatherConfiguration?
  var mail: MailConfiguration?
  var vpn: VPNConfiguration?
  var network: NetworkConfiguration?
  var volume: VolumeConfiguration?
  var refresh: RefreshPolicy?

  var active: [Item] { enabled ? [self] + (children ?? []).flatMap(\.active) : [] }

  var flattened: [Item] { [self] + (children ?? []).flatMap(\.flattened) }

  init(
    id: String,
    type: ItemType,
    enabled: Bool = true,
    text: String? = nil,
    symbol: ItemSymbol? = nil,
    symbolPosition: ItemSymbolPosition = .left,
    format: String? = nil,
    dateStyle: DateTimeStyle? = nil,
    timeStyle: DateTimeStyle? = nil,
    priority: Int = 0,
    style: ItemStyle? = nil,
    primaryAction: ItemAction? = nil,
    secondaryAction: ItemAction? = nil,
    popup: String? = nil,
    command: ShellCommand? = nil,
    children: [Item]? = nil,
    itemSpacing: Double? = nil,
    childStyle: ItemStyle? = nil,
    plugin: Plugin? = nil,
    frontApplication: FrontApplicationConfiguration? = nil,
    yabai: YabaiConfiguration? = nil,
    aerospace: AerospaceConfiguration? = nil,
    spaces: SpacesConfiguration? = nil,
    media: MediaConfiguration? = nil,
    throughput: ThroughputConfiguration? = nil,
    disk: DiskConfiguration? = nil,
    memory: MemoryConfiguration? = nil,
    cpu: CPUConfiguration? = nil,
    battery: BatteryConfiguration? = nil,
    bluetooth: BluetoothConfiguration? = nil,
    audioDevice: AudioDeviceConfiguration? = nil,
    weather: WeatherConfiguration? = nil,
    mail: MailConfiguration? = nil,
    vpn: VPNConfiguration? = nil,
    network: NetworkConfiguration? = nil,
    volume: VolumeConfiguration? = nil,
    refresh: RefreshPolicy? = nil
  ) {
    self.id = id
    self.type = type
    self.enabled = enabled

    self.text = text
    self.symbol = symbol
    self.symbolPosition = symbolPosition
    self.format = format
    self.dateStyle = dateStyle
    self.timeStyle = timeStyle
    self.priority = priority
    self.style = style

    self.primaryAction = primaryAction
    self.secondaryAction = secondaryAction
    self.popup = popup

    self.command = command
    self.children = children
    self.itemSpacing = itemSpacing
    self.childStyle = childStyle
    self.plugin = plugin
    self.frontApplication = frontApplication
    self.yabai = yabai
    self.aerospace = aerospace
    self.spaces = spaces
    self.media = media
    self.throughput = throughput
    self.disk = disk
    self.memory = memory
    self.cpu = cpu
    self.battery = battery
    self.bluetooth = bluetooth
    self.audioDevice = audioDevice
    self.weather = weather
    self.mail = mail
    self.vpn = vpn
    self.network = network
    self.volume = volume
    self.refresh = refresh
  }

  init(from decoder: any Decoder) throws {
    try RemovedTextSettings.validate(decoder)
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    type = try container.decode(ItemType.self, forKey: .type)
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true

    text = try container.decodeIfPresent(String.self, forKey: .text)
    symbol = try container.decodeIfPresent(ItemSymbol.self, forKey: .symbol)
    symbolPosition =
      try container.decodeIfPresent(ItemSymbolPosition.self, forKey: .symbolPosition)
      ?? .left
    format = try container.decodeIfPresent(String.self, forKey: .format)
    dateStyle = try container.decodeIfPresent(DateTimeStyle.self, forKey: .dateStyle)
    timeStyle = try container.decodeIfPresent(DateTimeStyle.self, forKey: .timeStyle)
    priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    style = try container.decodeIfPresent(ItemStyle.self, forKey: .style)

    primaryAction = try container.decodeIfPresent(ItemAction.self, forKey: .primaryAction)
    secondaryAction = try container.decodeIfPresent(ItemAction.self, forKey: .secondaryAction)
    popup = try container.decodeIfPresent(String.self, forKey: .popup)

    command = try container.decodeIfPresent(ShellCommand.self, forKey: .command)
    children = try container.decodeIfPresent([Item].self, forKey: .children)
    itemSpacing = try container.decodeIfPresent(Double.self, forKey: .itemSpacing)
    childStyle = try container.decodeIfPresent(ItemStyle.self, forKey: .childStyle)
    plugin = try container.decodeIfPresent(Plugin.self, forKey: .plugin)
    frontApplication = try container.decodeIfPresent(
      FrontApplicationConfiguration.self,
      forKey: .frontApplication
    )
    yabai = try container.decodeIfPresent(YabaiConfiguration.self, forKey: .yabai)
    aerospace = try container.decodeIfPresent(AerospaceConfiguration.self, forKey: .aerospace)
    spaces = try container.decodeIfPresent(SpacesConfiguration.self, forKey: .spaces)
    media = try container.decodeIfPresent(MediaConfiguration.self, forKey: .media)
    throughput = try container.decodeIfPresent(ThroughputConfiguration.self, forKey: .throughput)
    disk = try container.decodeIfPresent(DiskConfiguration.self, forKey: .disk)
    memory = try container.decodeIfPresent(MemoryConfiguration.self, forKey: .memory)
    cpu = try container.decodeIfPresent(CPUConfiguration.self, forKey: .cpu)
    battery = try container.decodeIfPresent(BatteryConfiguration.self, forKey: .battery)
    bluetooth = try container.decodeIfPresent(BluetoothConfiguration.self, forKey: .bluetooth)
    audioDevice = try container.decodeIfPresent(AudioDeviceConfiguration.self, forKey: .audioDevice)
    weather = try container.decodeIfPresent(WeatherConfiguration.self, forKey: .weather)
    mail = try container.decodeIfPresent(MailConfiguration.self, forKey: .mail)
    vpn = try container.decodeIfPresent(VPNConfiguration.self, forKey: .vpn)
    network = try container.decodeIfPresent(NetworkConfiguration.self, forKey: .network)
    volume = try container.decodeIfPresent(VolumeConfiguration.self, forKey: .volume)
    refresh = try container.decodeIfPresent(RefreshPolicy.self, forKey: .refresh)
  }
}

struct FrontApplicationConfiguration: Codable, Equatable, Sendable {
  var showIcon: Bool?
}

enum BarPosition: String, Codable, Sendable {
  case top, bottom, left, right

  var isVertical: Bool { self == .left || self == .right }
}

enum DisplaySelection: String, Codable, Sendable { case main, all, selected }

enum BarWindowLevel: String, Codable, CaseIterable, Sendable {
  case floating, statusBar, screenSaver
}

enum ItemSymbolPosition: String, Codable, CaseIterable, Sendable { case left, right }

enum ItemType: String, CaseIterable, Codable, Sendable {
  case weather, mail, datetime, divider, frontApplication, spacer, text, battery, volume, network,
    vpn,
    bluetooth,
    audioDevice,
    cpu,
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

enum DateTimeStyle: String, Codable, CaseIterable, Sendable {
  case none, short, medium, long, full
}
