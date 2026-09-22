import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("WidgetState")
struct NetworkWidgetTests {
  @MainActor
  @Test("presentation(for:): empty text preserves accessible connection status")
  func hiddenLabel() throws {
    let item = Item(id: "net", type: .network, text: "")
    let runtime = ProviderRuntime()

    for connection in NetworkConnection.allCases {
      runtime.updateWidgetState(.network(connection), for: .network)
      let result = try #require(runtime.presentation(for: item))

      #expect(result.text.isEmpty)
      #expect(!result.accessibilityLabel.isEmpty)
      #expect(result.symbol == connection.defaultSymbol)
    }
  }

  @Test("presentation(for:): interface filters report other active connections as disconnected")
  func interfaceFilters() {
    for interface in NetworkConnection.allCases where interface != .offline {
      let item = Item(
        id: "filtered",
        type: .network,
        network: NetworkConfiguration(interface: interface, hideWhenDisconnected: true)
      )

      for connection in NetworkConnection.allCases {
        let result = WidgetState.network(connection).presentation(for: item)
        let connected = interface == connection

        #expect(result.hidden == !connected)
        #expect(result.text.hasSuffix(connected ? " connected" : " disconnected"))
        #expect(result.accessibilityLabel == result.text)
        #expect(
          result.symbol
            == (connected
              ? interface.defaultSymbol : interface == .wifi ? "wifi.slash" : "network.slash")
        )
      }
    }
  }

  @Test(
    "presentation(for:): unfiltered network appearance follows every state and respects overrides"
  )
  func appearance() {
    for connection in NetworkConnection.allCases {
      var item = Item(
        id: "net",
        type: .network,
        symbol: "star",
        network: NetworkConfiguration(
          tints: [connection.rawValue: "#123456"],
          showSymbol: false,
          hideWhenDisconnected: true
        )
      )
      let result = WidgetState.network(connection).presentation(for: item)

      #expect(result.text == connection.text)
      #expect(result.symbol == nil)
      #expect(result.tint == "#123456")
      #expect(result.accessibilityLabel == connection.text)
      #expect(result.hidden == (connection == .offline))

      item.network?.showSymbol = true

      #expect(WidgetState.network(connection).presentation(for: item).symbol == "star")
    }
  }

  @Test(
    "NetworkConfiguration.validate: network configuration rejects invalid filters, state keys, and old Wi-Fi type"
  )
  func invalidConfiguration() {
    for json in [
      #"{"interface":"offline"}"#, #"{"interface":"invalid"}"#,
      #"{"tints":{"wifi":"red"}}"#,
      ##"{"tints":{"connected":"#123456"}}"##,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(NetworkConfiguration.self, from: Data(json.utf8))
        try settings.validate(path: "network")
      }
    }

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(Item.self, from: Data(#"{"id":"old","type":"wifi"}"#.utf8))
    }
  }

  @Test(
    "ProviderRuntime.presentation(for:): manual and event refresh keep filtered presentation state together"
  )
  @MainActor
  func filteredRefresh() throws {
    for mode in ["manual", "event"] {
      let configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(
          """
          {"schemaVersion":1,"bar":{},"items":{"right":[{"id":"net","type":"network","text":"{{#status=offline}}Unavailable{{/status}}{{^status=offline}}{{value}}{{/status}}","network":{"interface":"wifi","hideWhenDisconnected":true,"tints":{"offline":"#FF0000"}},"refresh":{"mode":"\(mode)"}}]}}
          """.utf8
        )
      )
      let runtime = ProviderRuntime()
      runtime.configure(configuration)
      defer { runtime.stop() }
      let item = try #require(configuration.items.active.first)
      runtime.updateWidgetState(.network(.wifi), for: .network)
      runtime.updateWidgetState(.network(.ethernet), for: .network)

      #expect(runtime.presentation(for: item)?.hidden == (mode == "event"))

      if mode == "manual" {
        #expect(runtime.presentation(for: item)?.text == "Wi-Fi connected")
        #expect(runtime.presentation(for: item)?.symbol == "wifi")
        #expect(runtime.presentation(for: item)?.tint == nil)
      }

      runtime.trigger("net")
      let result = try #require(runtime.presentation(for: item))

      #expect(result.hidden)
      #expect(result.text == "Unavailable")
      #expect(result.symbol == "wifi.slash")
      #expect(result.tint == "#FF0000")
    }
  }

  @Test(
    "NetworkConnection.classify: network classification handles offline and multiple interface types"
  )
  func classification() {
    #expect(
      NetworkConnection.classify(connected: false, wifi: true, ethernet: true, cellular: true)
        == .offline
    )
    #expect(
      NetworkConnection.classify(connected: true, wifi: true, ethernet: true, cellular: true)
        == .wifi
    )
    #expect(
      NetworkConnection.classify(connected: true, wifi: false, ethernet: true, cellular: true)
        == .ethernet
    )
    #expect(
      NetworkConnection.classify(connected: true, wifi: false, ethernet: false, cellular: true)
        == .cellular
    )
    #expect(
      NetworkConnection.classify(connected: true, wifi: false, ethernet: false, cellular: false)
        == .other
    )
  }

  @Test(
    "NetworkConfiguration.init(from:): maps round trip, support glyphs, and use defaults for omitted states"
  )
  func symbols() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        #"{"id":"net","type":"network","network":{"symbols":{"wifi":"custom","ethernet":{"glyph":"E","font":"Test","size":18}}}}"#
          .utf8
      )
    )

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    #expect(WidgetState.network(.wifi).presentation(for: item).symbol == "custom")
    #expect(
      WidgetState.network(.ethernet).presentation(for: item).symbol
        == .glyph("E", font: "Test", size: 18)
    )

    for connection in NetworkConnection.allCases {
      let state = WidgetState.network(connection)
      let defaults = Item(
        id: "net",
        type: .network,
        network: NetworkConfiguration(symbols: NetworkSymbols())
      )

      #expect(state.presentation(for: defaults).symbol == connection.defaultSymbol)

      if case .system(let name) = connection.defaultSymbol {
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
      }

      #expect(
        state.presentation(for: Item(id: "net", type: .network)).symbol == connection.defaultSymbol
      )
      #expect(
        state.presentation(for: Item(id: "net", type: .network, symbol: "star")).symbol == "star"
      )
    }
  }

  @Test(
    "NetworkConfiguration.validate: invalid keys, nested maps, and incomplete glyphs are rejected"
  )
  func invalidMaps() {
    for json in [
      #"{"wfi":"wifi"}"#,
      #"{"wifi":{"ethernet":"network"}}"#,
      #"{"wifi":{"glyph":"x"}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(
          NetworkConfiguration.self,
          from: Data("{\"symbols\":\(json)}".utf8)
        )
        try settings.validate(path: "network")
      }
    }

    let configuration = Configuration(
      bar: .init(),
      items: .init(
        right: [
          Item(id: "text", type: .text, network: NetworkConfiguration(symbols: NetworkSymbols()))
        ]
      )
    )

    #expect(throws: ConfigurationError.self) { try configuration.validate() }
  }

  @Test(
    "ProviderRuntime.presentation(for:): refresh captures interface changes even when connection text is unchanged"
  )
  @MainActor
  func refresh() throws {
    for mode in ["event", "manual"] {
      let configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(
          """
          {"schemaVersion":1,"bar":{},"items":{"right":[{"id":"net","type":"network","network":{"symbols":{}},"refresh":{"mode":"\(mode)"}}]}}
          """.utf8
        )
      )
      let runtime = ProviderRuntime()
      runtime.configure(configuration)
      defer { runtime.stop() }
      let item = try #require(configuration.items.active.first)
      runtime.updateWidgetState(.network(.ethernet), for: .network)
      runtime.updateWidgetState(.network(.cellular), for: .network)

      #expect(runtime.sharedValues[.network] == "Connected")
      #expect(
        runtime.presentation(for: item)?.symbol
          == (mode == "event"
            ? NetworkConnection.cellular.defaultSymbol : NetworkConnection.ethernet.defaultSymbol)
      )

      runtime.trigger("net")

      #expect(runtime.presentation(for: item)?.symbol == NetworkConnection.cellular.defaultSymbol)
    }
  }
}
