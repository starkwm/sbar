import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("Volume widget")
struct VolumeWidgetTests {
  @Test("volume levels use zero and three positive ranges")
  func levels() {
    let item = Item(id: "volume", type: .volume)
    let symbols = [
      "speaker.fill", "speaker.wave.1.fill", "speaker.wave.2.fill", "speaker.wave.3.fill",
    ]

    for (percentage, index) in [
      (-1, 0), (0, 0), (1, 1), (33, 1), (34, 2), (66, 2), (67, 3), (100, 3), (101, 3),
    ] {
      let state = WidgetState.volume(percentage: percentage, muted: false, available: true)
      let result = state.presentation(for: item)

      #expect(result.symbol == .system(symbols[index]))
      #expect(result.text == "Volume \(percentage)%")
      #expect(result.tint == nil)
      #expect(
        result
          == state.presentation(
            for: Item(id: "volume", type: .volume, volume: VolumeConfiguration())
          )
      )
    }
    for name in symbols + ["speaker.slash", "speaker.slash.fill"] {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }
  }

  @Test("volume state precedence, overrides, and visibility")
  func states() {
    var item = Item(
      id: "volume",
      type: .volume,
      volume: VolumeConfiguration(
        symbols: VolumeSymbols(muted: .system("m"), fixed: .system("f"), unavailable: .system("u")),
        tints: VolumeTints(muted: "#ff0000", fixed: "#00ff00", unavailable: "#0000ff")
      )
    )

    for (state, symbol, text, tint) in [
      (WidgetState.volume(percentage: 50, muted: true, available: true), "m", "Muted", "#ff0000"),
      (.volume(percentage: nil, muted: true, available: true), "m", "Muted", "#ff0000"),
      (.volume(percentage: nil, muted: false, available: true), "f", "Fixed volume", "#00ff00"),
      (.volume(percentage: 50, muted: true, available: false), "u", "No output", "#0000ff"),
    ] {
      let result = state.presentation(for: item)

      #expect(result.symbol == .system(symbol))
      #expect(result.text == text)
      #expect(result.accessibilityLabel == text)
      #expect(result.tint == tint)
    }

    let muted = WidgetState.volume(percentage: 50, muted: true, available: true)

    #expect(muted.presentation(for: item).text == "Muted")
    #expect(muted.presentation(for: item).accessibilityLabel == "Muted")

    item.symbol = "star"

    #expect(muted.presentation(for: item).symbol == "star")

    item.volume?.showSymbol = false

    #expect(muted.presentation(for: item).symbol == nil)

    let defaults = Item(id: "volume", type: .volume)

    #expect(muted.presentation(for: defaults).symbol == "speaker.slash.fill")
    #expect(
      WidgetState.volume(percentage: nil, muted: false, available: true).presentation(for: defaults)
        .symbol == "speaker.wave.3.fill"
    )
    #expect(
      WidgetState.volume(percentage: nil, muted: false, available: false).presentation(
        for: defaults
      ).symbol == "speaker.slash"
    )
  }

  @Test("volume glyph defaults, overrides, and configuration round trip")
  func configuration() throws {
    let json = #"""
      {"schemaVersion":1,"bar":{},"items":{"right":[{"id":"volume","type":"volume","volume":{
        "symbols":{"font":"Shared","size":18,
          "levels":["speaker.fill",{"glyph":"a"},{"glyph":"b","font":"Other"},{"glyph":"c","size":24}],
          "muted":{"glyph":"m"},"fixed":{"glyph":"f"},"unavailable":{"glyph":"u"}},
        "tints":{"muted":"#ff0000"}
      }}]}}
      """#
    let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    try config.validate()

    #expect(
      try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config)) == config
    )

    let item = try #require(config.items.active.first)
    let expected: [ItemSymbol] = [
      .system("speaker.fill"), .glyph("a", font: "Shared", size: 18),
      .glyph("b", font: "Other", size: 18), .glyph("c", font: "Shared", size: 24),
    ]

    for (percentage, symbol) in zip([0, 1, 34, 67], expected) {
      #expect(
        WidgetState.volume(percentage: percentage, muted: false, available: true).presentation(
          for: item
        ).symbol == symbol
      )
    }

    #expect(
      WidgetState.volume(percentage: 50, muted: true, available: true).presentation(for: item)
        .symbol == .glyph("m", font: "Shared", size: 18)
    )
    #expect(
      WidgetState.volume(percentage: nil, muted: false, available: true).presentation(for: item)
        .symbol == .glyph("f", font: "Shared", size: 18)
    )
    #expect(
      WidgetState.volume(percentage: nil, muted: false, available: false).presentation(for: item)
        .symbol == .glyph("u", font: "Shared", size: 18)
    )

    let wrongType = json.replacingOccurrences(
      of: "\"type\":\"volume\"",
      with: "\"type\":\"network\""
    )
    let invalid = try JSONDecoder().decode(Configuration.self, from: Data(wrongType.utf8))

    #expect(throws: ConfigurationError.self) { try invalid.validate() }
  }

  @Test("invalid volume settings are rejected")
  func invalidSettings() throws {
    for json in [
      #"{"symbols":{"levels":["speaker.fill"]}}"#,
      #"{"symbols":{"font":" "}}"#,
      #"{"symbols":{"size":73}}"#,
      #"{"symbols":{"muted":{"glyph":"x"}}}"#,
      #"{"symbols":{"font":"Shared","fixed":{"glyph":" "}}}"#,
      #"{"symbols":{"font":"Shared","unavailable":{"glyph":"x","size":7}}}"#,
      #"{"tints":{"muted":"red"}}"#,
      #"{"tints":{"fixed":"red"}}"#,
      #"{"tints":{"unavailable":"red"}}"#,
    ] {
      let config = try JSONDecoder().decode(VolumeConfiguration.self, from: Data(json.utf8))

      #expect(throws: ConfigurationError.self) { try config.validate(path: "volume") }
    }
  }

  @Test("volume refresh captures full state even while mute text is unchanged")
  @MainActor
  func refresh() throws {
    let runtime = ProviderRuntime()
    let json =
      #"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"volume","type":"volume","refresh":{"mode":"manual"}}]}}"#
    let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
    runtime.configure(config)
    defer { runtime.stop() }
    let item = try #require(config.items.active.first)
    runtime.updateWidgetState(.volume(percentage: 10, muted: true, available: true), for: .volume)
    runtime.trigger("volume")
    runtime.updateWidgetState(.volume(percentage: 90, muted: false, available: true), for: .volume)

    #expect(runtime.presentation(for: item)?.symbol == "speaker.slash.fill")

    runtime.trigger("volume")

    #expect(runtime.presentation(for: item)?.symbol == "speaker.wave.3.fill")

    runtime.updateWidgetState(.volume(percentage: 90, muted: true, available: true), for: .volume)
    runtime.updateWidgetState(.volume(percentage: 20, muted: true, available: true), for: .volume)

    #expect(runtime.widgetStates[.volume] == .volume(percentage: 20, muted: true, available: true))
    #expect(runtime.sharedValues[.volume] == "Muted")
  }
}
