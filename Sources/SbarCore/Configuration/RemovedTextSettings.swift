import Foundation

struct RemovedTextSettings {
  private struct Key: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
  }

  private static let fields: [String: [String]] = [
    "battery": ["showPercentage"],
    "volume": ["showPercentage"],
    "cpu": ["showLabel", "showPercentage"],
    "memory": ["format", "showLabel", "showValue"],
    "disk": ["format", "showLabel", "showValue"],
    "media": ["separator", "showTitle", "showArtist"],
    "vpn": ["showName", "showLabel", "labels"],
    "bluetooth": ["showName", "showLabel", "labels"],
    "network": ["showLabel", "labels"],
    "audioDevice": ["showLabel", "labels"],
    "command": ["showValue"],
    "plugin": ["showValue"],
    "spaces": ["format", "labels", "showValue"],
    "aerospace": ["format", "labels", "showValue"],
    "yabai": ["format", "showValue"],
  ]

  static func validate(_ decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: Key.self)
    func reject(_ key: Key, in values: KeyedDecodingContainer<Key>) throws {
      guard values.contains(key) else { return }
      throw DecodingError.dataCorruptedError(
        forKey: key,
        in: values,
        debugDescription:
          "This text setting was removed. Use the item's top-level 'text' template instead; use an empty string to hide the label. See docs/text-templates.md."
      )
    }
    try reject(Key("label"), in: container)
    for provider in fields.keys.sorted() {
      let key = Key(provider)
      guard container.contains(key), try !container.decodeNil(forKey: key) else { continue }
      let nested = try container.nestedContainer(keyedBy: Key.self, forKey: key)
      for field in fields[provider] ?? [] { try reject(Key(field), in: nested) }
    }
  }
}
