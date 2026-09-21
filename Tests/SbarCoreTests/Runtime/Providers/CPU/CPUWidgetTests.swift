import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("CPU widget")
struct CPUWidgetTests {
  @Test("sampling rounds, resets after failure and pauses, and bounds retained history")
  func sampling() {
    var provider = CPUProvider()

    #expect(provider.record(ticks: [0, 0, 0, 0], at: 0).samples.isEmpty)
    #expect(provider.record(ticks: [129, 0, 871, 0], at: 2).text == "CPU 13%")
    #expect(provider.record(ticks: nil, at: 4).text == "CPU —")
    #expect(provider.record(ticks: [200, 0, 900, 0], at: 6).samples.isEmpty)
    #expect(provider.record(ticks: [300, 0, 900, 0], at: 8).text == "CPU 100%")
    #expect(provider.record(ticks: [400, 0, 1000, 0], at: 20).samples.isEmpty)
    #expect(provider.record(ticks: [400, 0, 1100, 0], at: 22).text == "CPU 0%")
    #expect(provider.record(ticks: [400, 0, 1100, 0], at: 24).samples.isEmpty)

    for index in 1...40 {
      let state = provider.record(
        ticks: [400 + UInt32(index), 0, 1100, 0],
        at: 24 + Double(index * 2)
      )

      #expect(state.samples.count == min(index, 30))
    }

    provider.reset()

    #expect(provider.record(ticks: [1000, 0, 2000, 0], at: 106).samples.isEmpty)
  }

  @Test("counter wraparound preserves a valid delta")
  func wraparound() {
    #expect(
      CPUProvider.usage(
        previous: [UInt32.max - 4, 0, 100, 0],
        current: [5, 0, 110, 0]
      ) == 0.5
    )
  }

  @Test("smoothing averages available samples and rounding drives all appearance")
  func smoothing() {
    let state = CPUState(samples: [0, 59.6, 90])

    #expect(state.percentage(smoothingSamples: 1) == 90)
    #expect(state.percentage(smoothingSamples: 2) == 75)
    #expect(state.percentage(smoothingSamples: 30) == 50)

    let item = Item(
      id: "cpu",
      type: .cpu,
      cpu: CPUConfiguration(
        tints: CPUTints(medium: "#FFFF00", high: "#FF0000"),
        smoothingSamples: 2
      )
    )
    let result = state.presentation(for: item)

    #expect(result.text == "CPU 75%")
    #expect(result.tint == "#FFFF00")
    #expect(result.accessibilityLabel == "CPU usage 75 percent")
    #expect(state.text == "CPU 90%")
  }

  @Test("threshold symbols, glyph inheritance, and visibility use a consistent state")
  func appearance() {
    var item = Item(
      id: "cpu",
      type: .cpu,
      cpu: CPUConfiguration(
        symbols: CPUSymbols(
          font: "Shared",
          size: 18,
          low: .glyph("L"),
          medium: .system("exclamationmark"),
          high: .glyph("H", font: "Other"),
          unavailable: .system("questionmark")
        ),
        tints: CPUTints(low: "#00FF00", medium: "#FFFF00", high: "#FF0000", unavailable: "#888888")
      )
    )
    let cases: [(Double, ItemSymbol, String)] = [
      (59, .glyph("L", font: "Shared", size: 18), "#00FF00"),
      (59.6, "exclamationmark", "#FFFF00"),
      (84, "exclamationmark", "#FFFF00"),
      (85, .glyph("H", font: "Other", size: 18), "#FF0000"),
    ]

    for (value, symbol, tint) in cases {
      let result = CPUState(samples: [value]).presentation(for: item)

      #expect(result.symbol == symbol)
      #expect(result.tint == tint)
    }

    let unavailable = CPUState().presentation(for: item)

    #expect(unavailable.text == "CPU —")
    #expect(unavailable.symbol == "questionmark")
    #expect(unavailable.tint == "#888888")
    #expect(unavailable.accessibilityLabel == "CPU usage unavailable")
    #expect(CPUState(samples: [12]).presentation(for: item).text == "CPU 12%")

    item.symbol = "star"

    #expect(CPUState().presentation(for: item).symbol == "star")

    item.cpu?.showSymbol = false

    #expect(CPUState().presentation(for: item).symbol == nil)
    #expect(CPUState().presentation(for: item).accessibilityLabel == "CPU usage unavailable")

    for name in ["cpu", "questionmark"] {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }
  }

  @Test("CPU configuration round trips and rejects invalid ranges and appearance")
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"cpu","type":"cpu","cpu":{"symbols":{"font":"Shared","high":{"glyph":"H"}},"tints":{"high":"#FF0000"},"showSymbol":true,"warningThreshold":50,"highThreshold":90,"smoothingSamples":3}}"##
          .utf8
      )
    )
    try item.cpu?.validate(path: "cpu")

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    for json in [
      #"{"warningThreshold":-1}"#, #"{"highThreshold":101}"#,
      #"{"warningThreshold":85}"#, #"{"highThreshold":60}"#,
      #"{"smoothingSamples":0}"#, #"{"smoothingSamples":31}"#,
      #"{"symbols":{"font":" "}}"#, #"{"symbols":{"size":73}}"#,
      #"{"symbols":{"high":{"glyph":"H"}}}"#, #"{"tints":{"medium":"red"}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(CPUConfiguration.self, from: Data(json.utf8))
        try settings.validate(path: "cpu")
      }
    }

    let invalid = Configuration(
      bar: .init(),
      items: .init(right: [
        Item(id: "text", type: .text, cpu: CPUConfiguration())
      ])
    )

    #expect(throws: ConfigurationError.self) { try invalid.validate() }

    let state = CPUState(samples: [12])

    #expect(
      state.presentation(for: Item(id: "cpu", type: .cpu))
        == state.presentation(for: Item(id: "cpu", type: .cpu, cpu: CPUConfiguration()))
    )
  }

  @Test("manual refresh holds smoothing history and appearance until triggered")
  @MainActor
  func refresh() throws {
    let configuration = try JSONDecoder().decode(
      Configuration.self,
      from: Data(
        ##"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"cpu","type":"cpu","cpu":{"smoothingSamples":2,"tints":{"high":"#FF0000","unavailable":"#888888"}},"refresh":{"mode":"manual"}}]}}"##
          .utf8
      )
    )
    let runtime = ProviderRuntime()
    runtime.configure(configuration)
    defer { runtime.stop() }
    let item = try #require(configuration.items.active.first)
    runtime.updateWidgetState(.cpu(CPUState(samples: [80, 100])), for: .cpu)
    runtime.trigger("cpu")

    #expect(runtime.presentation(for: item)?.text == "CPU 90%")
    #expect(runtime.presentation(for: item)?.tint == "#FF0000")

    runtime.updateWidgetState(.cpu(CPUState()), for: .cpu)

    #expect(runtime.sharedValues[.cpu] == "CPU —")
    #expect(runtime.presentation(for: item)?.text == "CPU 90%")

    runtime.trigger("cpu")

    #expect(runtime.presentation(for: item)?.text == "CPU —")
    #expect(runtime.presentation(for: item)?.tint == "#888888")
  }
}
