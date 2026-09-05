import Foundation
import Testing

@testable import SbarCore

struct ProviderTests {
  @Test("CPU usage uses sample deltas, not lifetime totals")
  func cpuDelta() {
    #expect(
      SystemMetricsSampler.cpuUsage(previous: [100, 100, 800, 0], current: [120, 110, 870, 0])
        == 0.3
    )

    #expect(SystemMetricsSampler.cpuUsage(previous: [], current: [1, 2, 3, 4]) == nil)
    #expect(SystemMetricsSampler.cpuUsage(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]) == nil)
  }

  @MainActor @Test("Manual clock snapshots remain stable until explicitly triggered")
  func manualClock() async throws {
    let providers = ProviderRuntime()
    var config = BarConfiguration.default
    config.items.left = []
    config.items.right = [.init(id: "clock", type: .clock, refresh: .init(mode: .manual))]

    providers.configure(config)
    defer { providers.stop() }

    let initial = providers.itemDates["clock"]
    try await Task.sleep(for: .milliseconds(30))
    #expect(providers.itemDates["clock"] == initial)

    providers.trigger("clock")
    #expect(try #require(providers.itemDates["clock"]) > #require(initial))
  }

  @MainActor @Test("Cosmetic command edits do not rerun the process")
  func cosmeticChanges() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let providers = ProviderRuntime()
    defer {
      providers.stop()
      try? FileManager.default.removeItem(at: url)
    }

    let command = ShellCommandConfiguration(script: "printf x >> '\(url.path)'; printf ready")
    var config = BarConfiguration(
      bar: .init(),
      items: .init(left: [.init(id: "cmd", type: .command, command: command)])
    )

    providers.configure(config)

    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while providers.itemValues["cmd"] != "ready" && ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(20))
    }

    #expect(providers.itemValues["cmd"] == "ready")

    config.items.left[0].style = ItemStyle(tint: "#112233")
    providers.configure(config)
    try await Task.sleep(for: .milliseconds(100))

    #expect(try String(contentsOf: url, encoding: .utf8) == "x")
  }
}
