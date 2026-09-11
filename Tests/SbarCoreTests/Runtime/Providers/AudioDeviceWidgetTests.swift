import AppKit
import Testing

@testable import SbarCore

@Suite("Audio device widget")
struct AudioDeviceWidgetTests {
  @Test("items select output by default or input explicitly and keep names accessible")
  func devices() {
    let state = AudioDeviceState(
      output: .init(status: .available, id: 1, name: " Studio\n Display "),
      input: .init(status: .available, id: 2, name: "USB Microphone")
    )
    var item = Item(id: "audio", type: .audioDevice)
    #expect(state.text == "Studio Display")
    #expect(state.presentation(for: item).accessibilityLabel == "Output: Studio Display")
    item.audioDevice = AudioDeviceConfiguration(device: .input)
    #expect(state.presentation(for: item).text == "USB Microphone")
    #expect(state.presentation(for: item).accessibilityLabel == "Input: USB Microphone")
    let blank = AudioDeviceState(output: .init(status: .available, id: 1, name: " \n "))
    #expect(blank.text == "Unnamed device")
  }

  @Test("missing devices and read errors have distinct labels without stale device names")
  func states() {
    for kind in AudioDeviceKind.allCases {
      for status in AudioDeviceStatus.allCases {
        let endpoint = AudioDeviceEndpoint(status: status, id: 1, name: "Headset")
        let state = AudioDeviceState(output: endpoint, input: endpoint)
        let item = Item(
          id: "audio",
          type: .audioDevice,
          audioDevice: AudioDeviceConfiguration(device: kind, hideWhenDisconnected: true)
        )
        let presentation = state.presentation(for: item)
        let expected: String
        switch status {
        case .available: expected = "Headset"
        case .disconnected: expected = "No \(kind.rawValue)"
        case .unavailable: expected = "\(kind.label) unavailable"
        }
        #expect(presentation.text == expected)
        #expect(presentation.hidden == (status == .disconnected))
        #expect(presentation.symbol == status.defaultSymbol(for: kind))
        if case .system(let name) = presentation.symbol {
          #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
        }
      }
    }
  }

  @Test(
    "custom labels, glyphs, tints and icon-only items round trip without losing accessible names"
  )
  func appearance() throws {
    var item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"mic","type":"audioDevice","audioDevice":{"device":"input","symbols":{"font":"Test","size":18,"input":{"glyph":"M"}},"labels":{"available":"Mic"},"tints":{"available":"#00FF00"},"showLabel":false}}"##
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    let state = AudioDeviceState(input: .init(status: .available, id: 1, name: "USB Microphone"))
    let presentation = state.presentation(for: item)
    #expect(presentation.text.isEmpty)
    #expect(presentation.accessibilityLabel == "Input: USB Microphone")
    #expect(presentation.symbol == .glyph("M", font: "Test", size: 18))
    #expect(presentation.tint == "#00FF00")
    item.audioDevice?.showLabel = true
    #expect(state.presentation(for: item).text == "Mic")
    item.symbol = "star"
    #expect(state.presentation(for: item).symbol == "star")
    item.audioDevice?.showSymbol = false
    #expect(state.presentation(for: item).symbol == nil)
    item.audioDevice?.showSymbol = true
    item.symbol = nil
    item.audioDevice?.symbols = AudioDeviceSymbols()
    #expect(state.presentation(for: item).symbol == "mic.fill")
  }

  @Test("invalid device choices, appearance keys, colors and mismatched settings are rejected")
  func validation() {
    for settings in [
      ##"{"device":"speakers"}"##,
      ##"{"labels":{"connected":"On"}}"##,
      ##"{"tints":{"offline":"#FFFFFF"}}"##,
      ##"{"tints":{"available":"blue"}}"##,
      ##"{"symbols":{"available":"star"}}"##,
      ##"{"symbols":{"input":{"glyph":"M"}}}"##,
      ##"{"symbols":{"font":" "}}"##,
      ##"{"symbols":{"size":73}}"##,
    ] {
      #expect(throws: (any Error).self) {
        let value = try JSONDecoder().decode(
          AudioDeviceConfiguration.self,
          from: Data(settings.utf8)
        )
        try value.validate(path: "audioDevice")
      }
    }
    let configuration = Configuration(
      bar: .init(),
      items: .init(right: [Item(id: "text", type: .text, audioDevice: AudioDeviceConfiguration())])
    )
    #expect(throws: ConfigurationError.self) { try configuration.validate() }
  }

  @Test("schema describes both device selections and the supported state mappings")
  func schema() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let settings = try #require(definitions["audioDevice"] as? [String: Any])
    let properties = try #require(settings["properties"] as? [String: Any])
    #expect(
      Set(properties.keys) == [
        "device", "symbols", "labels", "tints", "showLabel", "showSymbol", "hideWhenDisconnected",
      ]
    )
    let device = try #require(properties["device"] as? [String: Any])
    let values = try #require(device["enum"] as? [Any])
    #expect(
      Set(values.compactMap { $0 as? String }) == Set(AudioDeviceKind.allCases.map(\.rawValue))
    )
    for field in ["labels", "tints"] {
      let map = try #require(properties[field] as? [String: Any])
      let states = try #require(map["properties"] as? [String: Any])
      #expect(Set(states.keys) == Set(AudioDeviceStatus.allCases.map(\.rawValue)))
      #expect(map["additionalProperties"] as? Bool == false)
    }
  }
}
