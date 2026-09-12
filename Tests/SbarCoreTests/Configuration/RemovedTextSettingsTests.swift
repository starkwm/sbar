import Foundation
import Testing

@testable import SbarCore

@Suite("Removed text settings")
struct RemovedTextSettingsTests {
  @Test(
    "retired settings report their full nested item path, including null values",
    arguments: [
      ("battery", "showPercentage"),
      ("volume", "showPercentage"),
      ("cpu", "showLabel"),
      ("cpu", "showPercentage"),
      ("memory", "format"),
      ("memory", "showLabel"),
      ("memory", "showValue"),
      ("disk", "format"),
      ("disk", "showLabel"),
      ("disk", "showValue"),
      ("media", "separator"),
      ("media", "showTitle"),
      ("media", "showArtist"),
      ("vpn", "showName"),
      ("vpn", "showLabel"),
      ("vpn", "labels"),
      ("bluetooth", "showName"),
      ("bluetooth", "showLabel"),
      ("bluetooth", "labels"),
      ("network", "showLabel"),
      ("network", "labels"),
      ("audioDevice", "showLabel"),
      ("audioDevice", "labels"),
      ("command", "showValue"),
      ("plugin", "showValue"),
      ("text", "label"),
      ("spaces", "format"),
      ("spaces", "showValue"),
      ("spaces", "labels"),
      ("aerospace", "format"),
      ("aerospace", "showValue"),
      ("aerospace", "labels"),
      ("yabai", "format"),
      ("yabai", "showValue"),

    ]
  )
  func migration(provider: String, field: String) throws {
    for value in [JSONValue.null, .bool(false)] {
      var item: [String: JSONValue] = ["id": .string("old"), "type": .string(provider)]
      if field == "label" { item[field] = value } else { item[provider] = .object([field: value]) }
      let json: JSONValue = .object([
        "schemaVersion": .number(1), "bar": .object([:]),
        "items": .object([
          "left": .array([
            .object([
              "id": .string("popup"), "type": .string("popup"), "children": .array([.object(item)]),
            ])
          ])
        ]),
      ])
      do {
        _ = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(json))
        Issue.record("Retired field was accepted: \(provider).\(field)")
      } catch {
        let message = ConfigurationStore.describe(error)
        let suffix = field == "label" ? field : "\(provider).\(field)"
        #expect(message.hasPrefix("items.left[0].children[0].\(suffix):"))
        #expect(message.contains("top-level 'text'"))
      }
    }
  }

  @MainActor
  @Test("a retired setting retains the last valid configuration during reload")
  func reload() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = ConfigurationStore(configurationURL: url)
    try Data(
      #"{"schemaVersion":1,"bar":{"height":48},"items":{"right":[{"id":"cpu","type":"cpu","text":"{{percentage}}%"}]}}"#
        .utf8
    ).write(to: url)
    store.load()
    let previous = store.configuration
    try Data(
      #"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"cpu","type":"cpu","cpu":{"showLabel":false}}]}}"#
        .utf8
    ).write(to: url)
    store.load()
    #expect(store.configuration == previous)
    #expect(store.errorMessage?.contains("items.right[0].cpu.showLabel") == true)
  }
}
