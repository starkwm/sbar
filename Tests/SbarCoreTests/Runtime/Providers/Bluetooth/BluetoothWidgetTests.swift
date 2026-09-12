import AppKit
import Testing

@testable import SbarCore

@Suite("Bluetooth widget")
struct BluetoothWidgetTests {
  @Test("power, connection and permission states have distinct labels and valid symbols")
  func states() {
    let labels: [BluetoothStatus: String] = [
      .on: "Bluetooth on", .off: "Bluetooth off", .connected: "Bluetooth connected",
      .unauthorized: "Bluetooth access denied", .unavailable: "Bluetooth unavailable",
    ]
    for status in BluetoothStatus.allCases {
      let presentation = BluetoothState(status: status).presentation(
        for: Item(id: "bt", type: .bluetooth)
      )
      #expect(presentation.text == labels[status])
      #expect(presentation.accessibilityLabel == presentation.text)
      #expect(presentation.symbol == status.defaultSymbol)
      if case .system(let name) = status.defaultSymbol {
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
      }
    }
  }

  @Test("connected names use a stable order and disappear when Bluetooth is off or inaccessible")
  func devices() {
    var state = BluetoothState(
      status: .connected,
      devices: [
        .init(id: "2", name: "Mouse"), .init(id: "1", name: "Keyboard"),
      ]
    )
    #expect(state.text == "Keyboard connected, Mouse connected")
    state.devices.reverse()
    #expect(state.text == "Keyboard connected, Mouse connected")
    for status in [BluetoothStatus.off, .unauthorized, .unavailable] {
      state.status = status
      #expect(!state.text.contains("Keyboard"))
      #expect(!state.text.contains("Mouse"))
    }
    state = BluetoothState(status: .connected, devices: [.init(id: "1", name: " \n ")])
    #expect(state.text == "Unnamed device connected")
  }

  @Test("icon-only appearance round trips and retains accessible device names")
  func appearance() throws {
    var item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"bt","type":"bluetooth","bluetooth":{"symbols":{"font":"Test","size":18,"connected":{"glyph":"B"}},"labels":{"connected":"linked"},"tints":{"connected":"#00FF00"},"showLabel":false,"hideWhenDisconnected":true}}"##
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    let state = BluetoothState(
      status: .connected,
      devices: [.init(id: "1", name: " Magic\n Keyboard ")]
    )
    let presentation = state.presentation(for: item)
    #expect(presentation.text.isEmpty)
    #expect(presentation.accessibilityLabel == "Magic Keyboard linked")
    #expect(presentation.symbol == .glyph("B", font: "Test", size: 18))
    #expect(presentation.tint == "#00FF00")
    #expect(!presentation.hidden)
    item.bluetooth?.showLabel = true
    item.bluetooth?.showName = false
    #expect(state.presentation(for: item).text == "Bluetooth linked")
    #expect(state.presentation(for: item).accessibilityLabel == "Magic Keyboard linked")
    item.symbol = "star"
    #expect(state.presentation(for: item).symbol == "star")
    item.bluetooth?.showSymbol = false
    #expect(state.presentation(for: item).symbol == nil)
  }

  @Test("hiding disconnected states keeps access failures visible and empty symbols use defaults")
  func hiding() {
    let item = Item(
      id: "bt",
      type: .bluetooth,
      bluetooth: BluetoothConfiguration(
        symbols: BluetoothSymbols(),
        hideWhenDisconnected: true
      )
    )
    for status in BluetoothStatus.allCases {
      let presentation = BluetoothState(status: status).presentation(for: item)
      #expect(presentation.hidden == (status == .on || status == .off))
      #expect(presentation.symbol == status.defaultSymbol)
    }
  }

  @Test("invalid state keys, colors, glyphs and mismatched item settings are rejected")
  func validation() {
    for settings in [
      ##"{"labels":{"poweredOn":"On"}}"##,
      ##"{"tints":{"offline":"#FFFFFF"}}"##,
      ##"{"tints":{"connected":"blue"}}"##,
      ##"{"symbols":{"online":"star"}}"##,
      ##"{"symbols":{"connected":{"glyph":"B"}}}"##,
      ##"{"symbols":{"font":" "}}"##,
      ##"{"symbols":{"size":7}}"##,
    ] {
      #expect(throws: (any Error).self) {
        let value = try JSONDecoder().decode(BluetoothConfiguration.self, from: Data(settings.utf8))
        try value.validate(path: "bluetooth")
      }
    }
    let configuration = Configuration(
      bar: .init(),
      items: .init(right: [
        Item(id: "text", type: .text, bluetooth: BluetoothConfiguration())
      ])
    )
    #expect(throws: ConfigurationError.self) { try configuration.validate() }
  }

  @Test("schema exposes Bluetooth settings and every status key")
  func schema() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let settings = try #require(definitions["bluetooth"] as? [String: Any])
    let properties = try #require(settings["properties"] as? [String: Any])
    #expect(
      Set(properties.keys) == [
        "symbols", "labels", "tints", "showName", "showLabel", "showSymbol", "hideWhenDisconnected",
      ]
    )
    for field in ["labels", "tints"] {
      let map = try #require(properties[field] as? [String: Any])
      let states = try #require(map["properties"] as? [String: Any])
      #expect(Set(states.keys) == Set(BluetoothStatus.allCases.map(\.rawValue)))
      #expect(map["additionalProperties"] as? Bool == false)
    }
  }
}
