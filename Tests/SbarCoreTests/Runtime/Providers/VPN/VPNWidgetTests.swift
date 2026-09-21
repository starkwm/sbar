import AppKit
import Testing

@testable import SbarCore

@Suite("VPN widget")
struct VPNWidgetTests {
  @Test("all connection states have distinct text and valid symbols")
  func states() {
    for status in VPNStatus.allCases {
      let state = VPNState(
        services: [.init(id: "work", name: "Work", status: status)],
        available: true
      )
      let presentation = state.presentation(for: Item(id: "vpn", type: .vpn))

      #expect(state.status == status)
      #expect(
        presentation.text
          == (status == .disconnected ? "VPN disconnected" : "Work \(status.rawValue)")
      )
      #expect(presentation.accessibilityLabel == presentation.text)
      #expect(presentation.symbol == status.defaultSymbol)

      if case .system(let name) = status.defaultSymbol {
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
      }
    }
  }

  @Test("multiple services retain names and states in a stable order")
  func multipleServices() {
    let state = VPNState(
      services: [
        .init(id: "work", name: "Work", status: .connecting),
        .init(id: "old", name: "Old", status: .disconnected),
        .init(id: "tail", name: "Tailscale", status: .connected),
        .init(id: "home", name: "Home", status: .disconnecting),
      ],
      available: true
    )

    #expect(state.status == .connected)
    #expect(state.text == "Home disconnecting, Tailscale connected, Work connecting")

    var reordered = state
    reordered.services.reverse()

    #expect(reordered.text == state.text)

    reordered.services.append(.init(id: "error", name: "Unknown", status: .unavailable))

    #expect(reordered.status == .unavailable)
    #expect(reordered.text.contains("Tailscale connected"))
    #expect(reordered.text.contains("Unknown unavailable"))
  }

  @Test("failed reads stay visible while known disconnected states can hide")
  func unavailable() {
    let item = Item(id: "vpn", type: .vpn, vpn: VPNConfiguration(hideWhenDisconnected: true))

    #expect(VPNState().text == "VPN unavailable")
    #expect(!VPNState().presentation(for: item).hidden)
    #expect(VPNState(available: true).text == "VPN disconnected")
    #expect(VPNState(available: true).presentation(for: item).hidden)

    for status in VPNStatus.allCases {
      let state = VPNState(
        services: [.init(id: "x", name: "Work", status: status)],
        available: true
      )

      #expect(state.presentation(for: item).hidden == (status == .disconnected))
    }

    let failed = VPNState(services: [.init(id: "x", name: "Work", status: .connected)])

    #expect(failed.text == "VPN unavailable")
  }

  @Test("appearance settings round trip and icon-only items retain accessible names")
  func appearance() throws {
    var item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"vpn","type":"vpn","vpn":{"symbols":{"font":"Test","size":18,"connected":{"glyph":"V"}},"tints":{"connected":"#00FF00"},"hideWhenDisconnected":true}}"##
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    let state = VPNState(
      services: [.init(id: "x", name: " Work\n VPN ", status: .connected)],
      available: true
    )
    let presentation = state.presentation(for: item)

    #expect(presentation.text == "Work VPN connected")
    #expect(presentation.accessibilityLabel == "Work VPN connected")
    #expect(presentation.symbol == .glyph("V", font: "Test", size: 18))
    #expect(presentation.tint == "#00FF00")
    #expect(!presentation.hidden)

    #expect(state.presentation(for: item).text == "Work VPN connected")
    #expect(state.presentation(for: item).accessibilityLabel == "Work VPN connected")

    item.symbol = "star"

    #expect(state.presentation(for: item).symbol == "star")

    item.vpn?.showSymbol = false

    #expect(state.presentation(for: item).symbol == nil)
  }

  @Test("blank names fall back to VPN and omitted symbols use defaults")
  func defaults() {
    let state = VPNState(
      services: [.init(id: "x", name: " \n ", status: .connected)],
      available: true
    )
    let item = Item(id: "vpn", type: .vpn, vpn: VPNConfiguration(symbols: VPNSymbols()))

    #expect(state.presentation(for: item).text == "VPN connected")
    #expect(state.presentation(for: item).symbol == VPNStatus.connected.defaultSymbol)
  }

  @Test("invalid state keys, tints, symbols and mismatched settings are rejected")
  func validation() throws {
    for settings in [
      ##"{"tints":{"offline":"#FFFFFF"}}"##,
      ##"{"tints":{"connected":"green"}}"##,
      ##"{"symbols":{"online":"lock"}}"##,
      ##"{"symbols":{"connected":{"glyph":"V"}}}"##,
      ##"{"symbols":{"font":" "}}"##,
      ##"{"symbols":{"size":73}}"##,
    ] {
      #expect(throws: (any Error).self) {
        let value = try JSONDecoder().decode(VPNConfiguration.self, from: Data(settings.utf8))
        try value.validate(path: "vpn")
      }
    }

    let configuration = Configuration(
      bar: .init(),
      items: .init(right: [
        Item(id: "text", type: .text, vpn: VPNConfiguration())
      ])
    )

    #expect(throws: ConfigurationError.self) { try configuration.validate() }
  }

  @Test("schema exposes VPN settings and all five status keys")
  func schema() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let vpn = try #require(definitions["vpn"] as? [String: Any])
    let properties = try #require(vpn["properties"] as? [String: Any])

    #expect(
      Set(properties.keys) == [
        "symbols", "tints", "showSymbol", "hideWhenDisconnected",
      ]
    )

    for field in ["tints"] {
      let map = try #require(properties[field] as? [String: Any])
      let states = try #require(map["properties"] as? [String: Any])

      #expect(Set(states.keys) == Set(VPNStatus.allCases.map(\.rawValue)))
      #expect(map["additionalProperties"] as? Bool == false)
    }
  }
}
