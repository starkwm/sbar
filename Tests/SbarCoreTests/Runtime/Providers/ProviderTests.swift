import Foundation
import Testing

@testable import SbarCore

@Suite("Providers")
struct ProviderTests {
  @Test(
    "CPUProvider.usage: uses sample deltas and rejects missing or unchanged samples"
  )
  func cpuDeltas() {
    #expect(
      CPUProvider.usage(previous: [100, 100, 800, 0], current: [120, 110, 870, 0])
        == 0.3
    )

    #expect(CPUProvider.usage(previous: [], current: [1, 2, 3, 4]) == nil)
    #expect(CPUProvider.usage(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]) == nil)
  }

  @MainActor
  @Test("ProviderRuntime.trigger: updates a manual clock snapshot only when triggered")
  func manualClock() async throws {
    let providers = ProviderRuntime()
    var config = Configuration.default
    config.items.left = []
    config.items.right = [.init(id: "clock", type: .datetime, refresh: .init(mode: .manual))]

    providers.configure(config)
    defer { providers.stop() }

    let initial = providers.itemDates["clock"]
    try await Task.sleep(for: .milliseconds(30))

    #expect(providers.itemDates["clock"] == initial)

    providers.trigger("clock")

    #expect(try #require(providers.itemDates["clock"]) > #require(initial))
  }

  @MainActor @Test("ProviderRuntime.configure: does not rerun commands after cosmetic edits")
  func cosmeticEdits() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let providers = ProviderRuntime()
    defer {
      providers.stop()
      try? FileManager.default.removeItem(at: url)
    }

    let command = ShellCommand(script: "printf x >> '\(url.path)'; printf ready")
    var config = Configuration(
      bar: .init(),
      items: .init(left: [.init(id: "cmd", type: .command, command: command)])
    )

    providers.configure(config)

    try await waitUntil { providers.itemValues["cmd"] == "ready" }

    config.items.left[0].style = ItemStyle(tint: "#112233")
    providers.configure(config)
    try await Task.sleep(for: .milliseconds(100))

    #expect(try String(contentsOf: url, encoding: .utf8) == "x")
  }
}
