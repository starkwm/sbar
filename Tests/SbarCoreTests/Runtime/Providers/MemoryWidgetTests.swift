import AppKit
import Darwin
import Foundation
import Testing

@testable import SbarCore

@Suite("Memory widget")
struct MemoryWidgetTests {
  @Test("used memory sums active, wired, and compressed pages using the host page size")
  func calculation() {
    for pageSize: UInt64 in [4096, 16384] {
      let state = MemoryProvider.state(
        active: 100,
        wired: 20,
        compressed: 30,
        pageSize: pageSize,
        totalBytes: 16 * 1024 * 1024
      )
      #expect(state.usedBytes == 150 * pageSize)
      #expect(state.totalBytes == 16 * 1024 * 1024)
      #expect(state.available)
    }
    #expect(
      MemoryProvider.state(active: 0, wired: 0, compressed: 0, pageSize: 4096, totalBytes: 4096)
        .value(format: .percentage) == "0%"
    )
    #expect(
      MemoryProvider.state(active: 1, wired: 0, compressed: 0, pageSize: 4096, totalBytes: 4096)
        .value(format: .percentage) == "100%"
    )
  }

  @Test("failed reads and invalid byte counts produce an unavailable reading")
  func unavailable() {
    #expect(!MemoryProvider.sample(host: mach_port_t(MACH_PORT_NULL)).available)
    for state in [
      MemoryProvider.state(active: 1, wired: 0, compressed: 0, pageSize: 0, totalBytes: 4096),
      MemoryProvider.state(active: 1, wired: 0, compressed: 0, pageSize: 4096, totalBytes: 0),
      MemoryProvider.state(active: 2, wired: 0, compressed: 0, pageSize: 4096, totalBytes: 4096),
      MemoryProvider.state(
        active: UInt32.max,
        wired: UInt32.max,
        compressed: UInt32.max,
        pageSize: UInt64.max,
        totalBytes: UInt64.max
      ),
      MemoryState(usedBytes: 1, totalBytes: UInt64.max),
    ] {
      #expect(!state.available)
      #expect(state.text == "RAM —")
      for format in [MemoryFormat.used, .percentage, .usedTotal] {
        #expect(state.value(format: format) == "—")
      }
    }
  }

  @Test("display modes format bytes, round percentages, and retain accessibility")
  func displayModes() {
    let state = MemoryState(usedBytes: 8 * 1024 * 1024 * 1024, totalBytes: 16 * 1024 * 1024 * 1024)
    let used = ByteCountFormatter.string(fromByteCount: 8 * 1024 * 1024 * 1024, countStyle: .memory)
    let total = ByteCountFormatter.string(
      fromByteCount: 16 * 1024 * 1024 * 1024,
      countStyle: .memory
    )
    #expect(state.value(format: .used) == used)
    #expect(state.value(format: .usedTotal) == "\(used) / \(total)")
    #expect(state.value(format: .percentage) == "50%")
    #expect(MemoryState(usedBytes: 129, totalBytes: 1000).value(format: .percentage) == "13%")
    var item = Item(
      id: "ram",
      type: .memory,
      memory: MemoryConfiguration(format: .percentage, showLabel: false)
    )
    let result = state.presentation(for: item)
    #expect(result.text == "50%")
    #expect(result.symbol == "memorychip")
    #expect(result.accessibilityLabel.contains(used))
    #expect(result.accessibilityLabel.contains(total))
    #expect(result.accessibilityLabel.contains("50%"))
    item.memory?.showValue = false
    #expect(state.presentation(for: item).text.isEmpty)
    #expect(state.presentation(for: item).accessibilityLabel == result.accessibilityLabel)
    item.memory?.showLabel = true
    #expect(state.presentation(for: item).text == "RAM")
    item.symbol = "star"
    #expect(state.presentation(for: item).symbol == "star")
    item.memory?.showSymbol = false
    #expect(state.presentation(for: item).symbol == nil)
    #expect(MemoryState().presentation(for: item).accessibilityLabel == "Memory usage unavailable")
    for name in ["memorychip", "questionmark"] {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }
  }

  @Test("appearance decodes, validates glyph inheritance, and round trips")
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        #"{"id":"ram","type":"memory","memory":{"format":"usedTotal","showLabel":false,"showValue":true,"showSymbol":true,"symbols":{"font":"Shared","size":18,"available":{"glyph":"M"},"unavailable":{"glyph":"?","font":"Other","size":24}}}}"#
          .utf8
      )
    )
    try item.memory?.validate(path: "memory")
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    let state = MemoryState(usedBytes: 1, totalBytes: 2)
    #expect(state.presentation(for: item).symbol == .glyph("M", font: "Shared", size: 18))
    #expect(MemoryState().presentation(for: item).symbol == .glyph("?", font: "Other", size: 24))
    #expect(
      state.presentation(for: Item(id: "ram", type: .memory))
        == state.presentation(for: Item(id: "ram", type: .memory, memory: MemoryConfiguration()))
    )
    for json in [
      #"{"format":"invalid"}"#, #"{"showValue":"false"}"#,
      #"{"symbols":{"font":" "}}"#, #"{"symbols":{"size":73}}"#,
      #"{"symbols":{"available":{"glyph":"M"}}}"#,
      #"{"symbols":{"font":"Shared","unavailable":{"glyph":""}}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let configuration = try JSONDecoder().decode(
          MemoryConfiguration.self,
          from: Data(json.utf8)
        )
        try configuration.validate(path: "memory")
      }
    }
    let invalid = Configuration(
      bar: .init(),
      items: .init(right: [
        Item(id: "text", type: .text, memory: MemoryConfiguration())
      ])
    )
    #expect(throws: ConfigurationError.self) { try invalid.validate() }
  }

  @Test("event and manual refresh propagate or hold unavailable readings as configured")
  @MainActor
  func refresh() throws {
    for mode in ["event", "manual"] {
      let configuration = try JSONDecoder().decode(
        Configuration.self,
        from: Data(
          """
          {"schemaVersion":1,"bar":{},"items":{"right":[{"id":"ram","type":"memory","memory":{"format":"percentage"},"refresh":{"mode":"\(mode)"}}]}}
          """.utf8
        )
      )
      let runtime = ProviderRuntime()
      runtime.configure(configuration)
      defer { runtime.stop() }
      let item = try #require(configuration.items.active.first)
      runtime.updateWidgetState(.memory(MemoryState(usedBytes: 1, totalBytes: 2)), for: .memory)
      runtime.trigger("ram")
      #expect(runtime.presentation(for: item)?.text == "RAM 50%")
      runtime.updateWidgetState(.memory(MemoryState()), for: .memory)
      #expect(runtime.sharedValues[.memory] == "RAM —")
      #expect(runtime.presentation(for: item)?.text == (mode == "event" ? "RAM —" : "RAM 50%"))
      runtime.trigger("ram")
      #expect(runtime.presentation(for: item)?.symbol == "questionmark")
      #expect(runtime.presentation(for: item)?.accessibilityLabel == "Memory usage unavailable")
      runtime.updateWidgetState(.memory(MemoryState(usedBytes: 3, totalBytes: 4)), for: .memory)
      runtime.trigger("ram")
      #expect(runtime.presentation(for: item)?.text == "RAM 75%")
    }
  }
}
