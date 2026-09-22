import AppKit
import Foundation
import Testing

@testable import SbarCore

@Suite("DiskState")
struct DiskWidgetTests {
  @Test("DiskState.value: capacity modes and rounding preserve valid boundary readings")
  func calculation() {
    let state = DiskState(freeBytes: 200_000_000, totalBytes: 1_000_000_000)

    #expect(state.available)
    #expect(state.freePercentage == 20)
    #expect(state.value(format: .percentage) == "80%")

    let formatted = { (bytes: Int64) in
      ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    #expect(state.value(format: .free) == formatted(200_000_000))
    #expect(state.value(format: .used) == formatted(800_000_000))
    #expect(state.value(format: .total) == formatted(1_000_000_000))
    #expect(DiskState(freeBytes: 871, totalBytes: 1000).value(format: .percentage) == "13%")
    #expect(DiskState(freeBytes: 0, totalBytes: 100).value(format: .percentage) == "100%")
    #expect(DiskState(freeBytes: 100, totalBytes: 100).value(format: .percentage) == "0%")

    for state in [
      DiskState(), DiskState(freeBytes: -1, totalBytes: 100),
      DiskState(freeBytes: 1, totalBytes: 0), DiskState(freeBytes: 101, totalBytes: 100),
    ] {
      #expect(!state.available)
      #expect(state.text == "Disk —")

      for format in [DiskFormat.free, .used, .total, .percentage] {
        #expect(state.value(format: format) == "—")
      }
    }
  }

  @Test(
    "presentation(for:): low-space thresholds use unrounded free percentage and appearance retains accessibility"
  )
  func appearance() {
    var item = Item(
      id: "disk",
      type: .disk,
      disk: DiskConfiguration(
        symbols: AvailabilitySymbols(
          font: "Shared",
          size: 18,
          available: .glyph("D"),
          unavailable: .system("questionmark")
        ),
        tints: DiskTints(
          normal: "#00FF00",
          warning: "#FFFF00",
          critical: "#FF0000",
          unavailable: "#888888"
        )
      )
    )

    for (free, tint) in [
      (201, "#00FF00"), (200, "#FFFF00"), (101, "#FFFF00"), (100, "#FF0000"), (0, "#FF0000"),
    ] {
      let result = DiskState(freeBytes: Int64(free), totalBytes: 1000).presentation(for: item)

      #expect(result.tint == tint)
      #expect(result.symbol == .glyph("D", font: "Shared", size: 18))
      #expect(result.text.hasSuffix(" free"))
    }

    #expect(DiskState().presentation(for: item).tint == "#888888")
    #expect(DiskState().presentation(for: item).text == "— unavailable")
    #expect(DiskState().presentation(for: item).accessibilityLabel.contains("unavailable"))

    item.symbol = "star"

    #expect(DiskState().presentation(for: item).symbol == "star")

    item.disk?.showSymbol = false

    #expect(DiskState().presentation(for: item).symbol == nil)

    for name in ["internaldrive", "questionmark"] {
      #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }
  }

  @Test(
    "DiskProvider.volume: native sampling rejects absent paths and shares existing directories on a volume"
  )
  func nativePaths() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let child = root.appendingPathComponent("child")
    try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)

    #expect(DiskProvider.volume(for: root.appendingPathComponent("missing").path) == nil)

    let first = try #require(DiskProvider.volume(for: root.path))
    let second = try #require(DiskProvider.volume(for: child.path))

    #expect(first.identity == second.identity)
    #expect(DiskProvider.read(first).available)
  }

  @Test(
    "DiskProvider.sample: paths on the same volume share a read; missing paths stay unavailable and recover"
  )
  func sharedVolumes() {
    var provider = DiskProvider()
    var reads = 0
    var mounted = true
    let resolve: (String) -> DiskVolume? = { path in
      if path == "/missing" { return nil }

      return DiskVolume(
        identity: mounted ? "external" : "root",
        mountPath: mounted ? "/drive" : "/",
        path: path
      )
    }
    let read: (DiskVolume) -> DiskState = { _ in
      reads += 1

      return DiskState(freeBytes: 20, totalBytes: 100)
    }
    let paths: Set<String> = ["/drive/a", "/drive/b", "/missing"]
    let first = provider.sample(paths: paths, resolve: resolve, read: read)

    #expect(reads == 1)
    #expect(first["/drive/a"] == first["/drive/b"])
    #expect(first["/missing"]?.available == false)

    mounted = false
    let removed = provider.sample(paths: paths, resolve: resolve, read: read)

    #expect(reads == 1)
    #expect(removed.values.allSatisfy { !$0.available })

    mounted = true

    #expect(
      provider.sample(paths: paths, resolve: resolve, read: read)["/drive/a"]?.available == true
    )
    #expect(reads == 2)
  }

  @Test(
    "DiskProvider.sample: failed reads and a mount change during sampling cannot publish a stale volume"
  )
  func readFailure() {
    var provider = DiskProvider()
    let volume = DiskVolume(identity: "external", mountPath: "/drive", path: "/drive")

    #expect(
      provider.sample(paths: ["/drive"], resolve: { _ in volume }, read: { _ in DiskState() })[
        "/drive"
      ]?.available == false
    )

    var changed = false
    let result = provider.sample(
      paths: ["/drive"],
      resolve: { _ in
        changed ? DiskVolume(identity: "root", mountPath: "/", path: "/drive") : volume
      },
      read: { _ in
        changed = true

        return DiskState(freeBytes: 1, totalBytes: 2)
      }
    )

    #expect(result["/drive"]?.available == false)
  }

  @Test(
    "DiskConfiguration.validate: configuration validates paths and thresholds and round trips glyphs"
  )
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"disk","type":"disk","disk":{"path":"~/Downloads","showSymbol":true,"warningThreshold":25,"criticalThreshold":5,"tints":{"warning":"#FFFF00"},"symbols":{"font":"Shared","available":{"glyph":"D"}}}}"##
          .utf8
      )
    )
    try item.disk?.validate(path: "disk")

    #expect(item.disk?.resolvedPath == NSHomeDirectory() + "/Downloads")
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    for json in [
      #"{"path":""}"#, #"{"path":"relative"}"#,
      #"{"warningThreshold":-1}"#, #"{"criticalThreshold":101}"#,
      #"{"warningThreshold":10}"#, #"{"criticalThreshold":20}"#,
      #"{"tints":{"warning":"red"}}"#, #"{"symbols":{"available":{"glyph":"D"}}}"#,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(DiskConfiguration.self, from: Data(json.utf8))
        try settings.validate(path: "disk")
      }
    }

    let invalid = Configuration(
      bar: .init(),
      items: .init(right: [Item(id: "text", type: .text, disk: DiskConfiguration())])
    )

    #expect(throws: ConfigurationError.self) { try invalid.validate() }
  }

  @Test(
    "ProviderRuntime.presentation(for:): multiple disk items keep independent refresh state and discard old paths on reload"
  )
  @MainActor
  func refresh() throws {
    var configuration = try JSONDecoder().decode(
      Configuration.self,
      from: Data(
        #"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"a","type":"disk","text":"{{percentage}}% used","disk":{"path":"/a"},"refresh":{"mode":"manual"}},{"id":"b","type":"disk","text":"{{percentage}}% used","disk":{"path":"/b"},"refresh":{"mode":"event"}}]}}"#
          .utf8
      )
    )
    let runtime = ProviderRuntime()
    runtime.configure(configuration)
    defer { runtime.stop() }
    var a = configuration.items.active[0]
    let b = configuration.items.active[1]
    runtime.updateDiskStates([
      "/a": DiskState(freeBytes: 20, totalBytes: 100),
      "/b": DiskState(freeBytes: 50, totalBytes: 100),
    ])
    runtime.trigger("a")

    #expect(runtime.presentation(for: a)?.text == "80% used")
    #expect(runtime.presentation(for: b)?.text == "50% used")

    runtime.updateDiskStates(["/a": DiskState(), "/b": DiskState(freeBytes: 10, totalBytes: 100)])

    #expect(runtime.presentation(for: a)?.text == "80% used")
    #expect(runtime.presentation(for: b)?.text == "90% used")

    runtime.trigger("a")

    #expect(runtime.presentation(for: a)?.symbol == "questionmark")

    configuration.items.right[0].disk?.path = "/new"
    runtime.configure(configuration)
    a = configuration.items.active[0]
    runtime.updateDiskStates(["/a": DiskState(freeBytes: 20, totalBytes: 100), "/b": DiskState()])
    runtime.trigger("a")

    #expect(runtime.presentation(for: a)?.symbol == "questionmark")

    runtime.updateDiskStates(["/new": DiskState(freeBytes: 90, totalBytes: 100), "/b": DiskState()])
    runtime.trigger("a")

    #expect(runtime.presentation(for: a)?.text == "10% used")
  }
}
