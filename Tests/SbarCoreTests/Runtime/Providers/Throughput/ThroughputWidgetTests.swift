import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("Throughput widget")
struct ThroughputWidgetTests {
  @Test("interface appearance and disappearance cannot create aggregate counter spikes")
  func interfaceChanges() {
    var provider = ThroughputProvider()

    #expect(
      provider.record(counters: ["en0": .init(received: 100, sent: 50)], at: 0).rate(
        interfaces: nil,
        smoothingSamples: 1
      ) == nil
    )

    let added = provider.record(
      counters: [
        "en0": .init(received: 300, sent: 150),
        "en1": .init(received: 1_000_000, sent: 2_000_000),
      ],
      at: 2
    )

    #expect(
      added.rate(interfaces: nil, smoothingSamples: 1) == ThroughputRate(download: 100, upload: 50)
    )
    #expect(added.rate(interfaces: ["en1"], smoothingSamples: 1) == nil)

    let both = provider.record(
      counters: [
        "en0": .init(received: 500, sent: 250),
        "en1": .init(received: 1_000_400, sent: 2_000_100),
      ],
      at: 4
    )

    #expect(
      both.rate(interfaces: nil, smoothingSamples: 1) == ThroughputRate(download: 300, upload: 100)
    )
    #expect(
      both.rate(interfaces: ["en1"], smoothingSamples: 1)
        == ThroughputRate(download: 200, upload: 50)
    )

    let removed = provider.record(counters: ["en0": .init(received: 700, sent: 350)], at: 6)

    #expect(
      removed.rate(interfaces: nil, smoothingSamples: 1)
        == ThroughputRate(download: 100, upload: 50)
    )
    #expect(removed.rate(interfaces: ["en0", "en1"], smoothingSamples: 1) == nil)
  }

  @Test("counter resets, replacement, failures, and timing gaps clear stale history")
  func recovery() {
    var provider = ThroughputProvider()
    _ = provider.record(counters: ["en0": .init(received: 100, sent: 100)], at: 0)

    #expect(
      provider.record(counters: ["en0": .init(received: 300, sent: 100)], at: 2).rate(
        interfaces: nil,
        smoothingSamples: 1
      )?.download == 100
    )
    #expect(
      provider.record(counters: ["en0": .init(received: 1, sent: 1)], at: 4).rate(
        interfaces: nil,
        smoothingSamples: 1
      ) == nil
    )
    #expect(
      provider.record(counters: ["en0": .init(received: 1, sent: 1)], at: 6).rate(
        interfaces: nil,
        smoothingSamples: 1
      ) == ThroughputRate(download: 0, upload: 0)
    )
    #expect(
      provider.record(
        counters: ["en0": .init(received: 1_000_000, sent: 1_000_000, index: 2)],
        at: 8
      ).rate(interfaces: nil, smoothingSamples: 1) == nil
    )
    #expect(provider.record(counters: nil, at: 10).text == "Throughput —")
    #expect(
      provider.record(counters: ["en0": .init(received: 200, sent: 100)], at: 12).text
        == "Throughput —"
    )
    #expect(
      provider.record(counters: ["en0": .init(received: 600, sent: 300)], at: 16).rate(
        interfaces: nil,
        smoothingSamples: 1
      ) == ThroughputRate(download: 100, upload: 50)
    )
    #expect(
      provider.record(counters: ["en0": .init(received: 1000, sent: 500)], at: 30).text
        == "Throughput —"
    )
    #expect(
      provider.record(counters: ["en0": .init(received: 1200, sent: 600)], at: 30).text
        == "Throughput —"
    )
    #expect(
      provider.record(counters: ["en0": .init(received: 1400, sent: 700)], at: 29).text
        == "Throughput —"
    )

    provider.reset()

    #expect(
      provider.record(counters: ["en0": .init(received: 1600, sent: 800)], at: 32).text
        == "Throughput —"
    )
    #expect(provider.record(counters: [:], at: 34).text == "Throughput —")
  }

  @Test("history is bounded and smoothing is independently selected per item")
  func smoothing() {
    var provider = ThroughputProvider()
    var counters = ThroughputCounters(received: 0, sent: 0)
    _ = provider.record(counters: ["en0": counters], at: 0)

    for index in 1...40 {
      counters.received += UInt64(index * 2)
      counters.sent += UInt64(index * 4)
      let state = provider.record(counters: ["en0": counters], at: Double(index * 2))

      #expect(state.histories["en0"]?.count == min(index, 30))
      #expect(state.rate(interfaces: nil, smoothingSamples: 1)?.download == Double(index))

      if index > 1 {
        #expect(
          state.rate(interfaces: ["en0"], smoothingSamples: 2)?.download == Double(index) - 0.5
        )
      }
    }
  }

  @Test("automatic units preserve small rates and distinguish bits from bytes")
  func formatting() {
    #expect(ThroughputState.format(0, unit: .bytes) == "0 B/s")
    #expect(ThroughputState.format(0.5, unit: .bytes) == "0.5 B/s")
    #expect(ThroughputState.format(512, unit: .bytes) == "512 B/s")
    #expect(ThroughputState.format(1536, unit: .bytes) == "1.5 KiB/s")
    #expect(ThroughputState.format(1024 * 1024, unit: .bytes) == "1 MiB/s")
    #expect(ThroughputState.format(1023.99, unit: .bytes) == "1 KiB/s")
    #expect(ThroughputState.format(125_000, unit: .bits) == "1 Mbit/s")
  }

  @Test("direction visibility, glyphs, units, and overrides retain accessible rates")
  func appearance() {
    let state = ThroughputState(histories: ["en0": [.init(download: 1536, upload: 512)]])
    var item = Item(
      id: "net",
      type: .throughput,
      throughput: ThroughputConfiguration(
        symbols: ThroughputSymbols(
          font: "Shared",
          size: 18,
          download: .glyph("D"),
          upload: .glyph("U", font: "Other")
        )
      )
    )
    item.text = "{{#transfers}}{{symbol}}{{number}}{{/transfers}}"
    let result = state.presentation(for: item)

    #expect(
      result.segments == [
        WidgetSegment(text: "1.5", symbol: .glyph("D", font: "Shared", size: 18)),
        WidgetSegment(text: "512", symbol: .glyph("U", font: "Other", size: 18)),
      ]
    )
    #expect(result.accessibilityLabel == "Download 1.5 KiB/s, Upload 512 B/s")

    item.text =
      "{{#transfers}}{{#direction=download}}{{symbol}}{{number}}{{/direction}}{{/transfers}}"

    #expect(state.presentation(for: item).segments.count == 1)

    item.text = "{{#transfers}}{{#direction=download}}{{symbol}}{{/direction}}{{/transfers}}"

    #expect(state.presentation(for: item).text.isEmpty)
    #expect(state.presentation(for: item).segments.first?.symbol != nil)

    item.symbol = "star"

    #expect(state.presentation(for: item).symbol == "star")
    #expect(state.presentation(for: item).segments.isEmpty)

    item.throughput?.showSymbol = false

    #expect(state.presentation(for: item).symbol == nil)
    #expect(
      state.presentation(for: item).accessibilityLabel == "Download 1.5 KiB/s, Upload 512 B/s"
    )
    #expect(
      ThroughputState().presentation(for: item).accessibilityLabel
        == "Network throughput unavailable"
    )

    for name in ["arrow.down", "arrow.up", "questionmark"] {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }
  }

  @Test("templates keep scaled numbers and units aligned and handle missing readings")
  func templates() throws {
    let state = ThroughputState(histories: ["en0": [.init(download: 1023.99, upload: 0)]])
    var item = Item(id: "net", type: .throughput)
    item.text =
      "{{#available}}{{download.value}}|{{download.unit}}|{{upload}}{{/available}}{{^available}}Offline{{/available}}"

    #expect(state.presentation(for: item).text == "1|KiB/s|0 B/s")
    #expect(ThroughputState().presentation(for: item).text == "Offline")

    item.throughput = ThroughputConfiguration(unit: .bits)
    item.text =
      "{{#transfers}}{{index}}:{{direction}}={{number}} {{unit}}{{#separator}};{{/separator}}{{/transfers}}"

    #expect(state.presentation(for: item).text == "1:download=8.2 kbit/s;2:upload=0 bit/s")
    #expect(ThroughputState().presentation(for: item).text == "")

    for source in [
      "{{#transfers}}{{#symbol}}x{{/symbol}}{{/transfers}}",
      "{{#direction=sideways}}x{{/direction}}",
    ] {
      #expect(throws: ConfigurationError.self) {
        try TextTemplate(
          source,
          fields: TextTemplate.fields(for: .throughput),
          allowedValues: TextTemplate.allowedValues(for: .throughput)
        )
      }
    }
  }

  @Test("configuration round trips and rejects invalid selections and settings")
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        #"{"id":"net","type":"throughput","throughput":{"interfaces":["en0"],"unit":"bits","smoothingSamples":3,"showSymbol":true,"symbols":{"font":"Shared","download":{"glyph":"D"}}}}"#
          .utf8
      )
    )
    try item.throughput?.validate(path: "throughput")

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    for json in [
      #"{"interfaces":[]}"#, #"{"interfaces":["en0","en0"]}"#,
      #"{"interfaces":[" "]}"#, #"{"unit":"invalid"}"#,
      #"{"smoothingSamples":0}"#, #"{"smoothingSamples":31}"#,
      #"{"symbols":{"font":" "}}"#, #"{"symbols":{"size":73}}"#,
      #"{"symbols":{"download":{"glyph":"D"}}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(ThroughputConfiguration.self, from: Data(json.utf8))
        try settings.validate(path: "throughput")
      }
    }

    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "text", type: .text, throughput: ThroughputConfiguration())])
      ).validate()
    }
  }

  @Test("refresh snapshots preserve selected rates and unavailable transitions")
  @MainActor
  func refresh() throws {
    for mode in ["manual", "event"] {
      let configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(
          """
          {"schemaVersion":1,"bar":{},"items":{"right":[{"id":"net","type":"throughput","throughput":{"interfaces":["en0"],"smoothingSamples":2},"refresh":{"mode":"\(mode)"}}]}}
          """.utf8
        )
      )
      let runtime = ProviderRuntime()
      runtime.configure(configuration)
      defer { runtime.stop() }
      let item = try #require(configuration.items.active.first)
      runtime.updateWidgetState(
        .throughput(
          ThroughputState(histories: [
            "en0": [.init(download: 100, upload: 50), .init(download: 300, upload: 150)]
          ])
        ),
        for: .throughput
      )
      runtime.trigger("net")

      #expect(runtime.presentation(for: item)?.segments.first?.text == "200 B/s")

      runtime.updateWidgetState(.throughput(ThroughputState()), for: .throughput)

      #expect(runtime.sharedValues[.throughput] == "Throughput —")
      #expect(runtime.presentation(for: item)?.segments.isEmpty == (mode == "event"))

      runtime.trigger("net")

      #expect(runtime.presentation(for: item)?.symbol == "questionmark")
    }
  }
}
