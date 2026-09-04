import Foundation

struct BarConfiguration: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let `default` = BarConfiguration(
        schemaVersion: currentSchemaVersion,
        bar: .init(),
        items: .init(
            left: [.init(id: "app", type: .frontApplication, label: "StarkBar")],
            right: [.init(id: "divider", type: .divider), .init(id: "clock", type: .clock, format: "HH:mm")]
        )
    )

    var schemaVersion: Int
    var bar: BarSettings
    var items: ItemSections

    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ConfigurationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard (20...96).contains(bar.height) else {
            throw ConfigurationError.invalidBarHeight(bar.height)
        }
        var identifiers = Set<String>()
        for (section, entries) in [("left", items.left), ("center", items.center), ("right", items.right)] {
            for (index, item) in entries.enumerated() {
                let path = "items.\(section)[\(index)].id"
                guard !item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ConfigurationError.invalidItemIdentifier(path: path, reason: "Must not be empty.")
                }
                guard identifiers.insert(item.id).inserted else {
                    throw ConfigurationError.invalidItemIdentifier(path: path, reason: "Duplicate ID '\(item.id)'.")
                }
            }
        }
    }
}

struct BarSettings: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey { case position, height, displays }

    var position: BarPosition = .top
    var height: Double = 32
    var displays: DisplaySelection = .all

    init(position: BarPosition = .top, height: Double = 32, displays: DisplaySelection = .all) {
        self.position = position
        self.height = height
        self.displays = displays
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decodeIfPresent(BarPosition.self, forKey: .position) ?? .top
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 32
        displays = try container.decodeIfPresent(DisplaySelection.self, forKey: .displays) ?? .all
    }
}

struct ItemSections: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey { case left, center, right }

    var left: [ItemConfiguration] = []
    var center: [ItemConfiguration] = []
    var right: [ItemConfiguration] = []

    var all: [ItemConfiguration] { left + center + right }

    init(left: [ItemConfiguration] = [], center: [ItemConfiguration] = [], right: [ItemConfiguration] = []) {
        self.left = left
        self.center = center
        self.right = right
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        left = try container.decodeIfPresent([ItemConfiguration].self, forKey: .left) ?? []
        center = try container.decodeIfPresent([ItemConfiguration].self, forKey: .center) ?? []
        right = try container.decodeIfPresent([ItemConfiguration].self, forKey: .right) ?? []
    }
}

struct ItemConfiguration: Codable, Equatable, Identifiable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case enabled, format, id, label, priority, symbol, type
    }

    var id: String
    var type: ItemType
    var enabled: Bool = true
    var label: String?
    var symbol: String?
    var format: String?
    var priority: Int = 0

    init(
        id: String,
        type: ItemType,
        enabled: Bool = true,
        label: String? = nil,
        symbol: String? = nil,
        format: String? = nil,
        priority: Int = 0
    ) {
        self.id = id
        self.type = type
        self.enabled = enabled
        self.label = label
        self.symbol = symbol
        self.format = format
        self.priority = priority
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
    }
}

enum BarPosition: String, Codable, Sendable { case top, bottom }
enum DisplaySelection: String, Codable, Sendable { case main, all }
enum ItemType: String, CaseIterable, Codable, Sendable { case clock, divider, frontApplication, spacer, text }

enum ConfigurationError: Error, Equatable, LocalizedError {
    case invalidItemIdentifier(path: String, reason: String)
    case invalidBarHeight(Double)
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .invalidItemIdentifier(path, reason): "\(path): \(reason)"
        case let .invalidBarHeight(height): "bar.height: \(height) is outside the supported range of 20...96."
        case let .unsupportedSchemaVersion(version): "schemaVersion: \(version) is not supported."
        }
    }
}
