import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("Network symbols")
struct NetworkWidgetTests {
  @Test("network classification handles offline and multiple interface types")
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

  @Test("maps round trip, support glyphs, and use defaults for omitted states")
  func symbols() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        #"{"id":"net","type":"network","symbol":{"wifi":"custom","ethernet":{"glyph":"E","font":"Test","size":18}}}"#
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
      let defaults = Item(id: "net", type: .network, symbol: .network([:]))
      #expect(state.presentation(for: defaults).symbol == connection.defaultSymbol)
      if case .system(let name) = connection.defaultSymbol {
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
      }
      #expect(state.presentation(for: Item(id: "net", type: .network)).symbol == nil)
      #expect(
        state.presentation(for: Item(id: "net", type: .network, symbol: "star")).symbol == "star"
      )
    }
  }

  @Test("invalid keys, nested maps, and incomplete glyphs are rejected")
  func invalidMaps() {
    for json in [
      #"{"wfi":"wifi"}"#,
      #"{"wifi":{"ethernet":"network"}}"#,
      #"{"wifi":{"glyph":"x"}}"#,
    ] {
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(ItemSymbol.self, from: Data(json.utf8))
      }
    }
    let configuration = Configuration(
      bar: .init(),
      items: .init(
        right: [Item(id: "text", type: .text, symbol: .network([:]))]
      )
    )
    #expect(throws: ConfigurationError.self) { try configuration.validate() }
  }

  @Test("refresh captures interface changes even when connection text is unchanged")
  @MainActor
  func refresh() throws {
    for mode in ["event", "manual"] {
      let configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(
          """
          {"schemaVersion":1,"bar":{},"items":{"right":[{"id":"net","type":"network","symbol":{},"refresh":{"mode":"\(mode)"}}]}}
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
