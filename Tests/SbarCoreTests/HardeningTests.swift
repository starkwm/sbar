import Foundation
import Testing

@testable import SbarCore

struct HardeningTests {
  @Test("Version one commands migrate recursively without rewriting files")
  func migration() throws {
    let json =
      #"{"schemaVersion":1,"bar":{},"items":{"left":[{"id":"group","type":"group","children":[{"id":"c","type":"command","command":{"script":"date","interval":12,"event":"refresh"}}]}]}}"#
    let configuration = try JSONDecoder().decode(BarConfiguration.self, from: Data(json.utf8))
    try configuration.validate()
    let item = try #require(configuration.items.left.first?.children?.first)
    #expect(configuration.schemaVersion == 2)
    #expect(item.refresh == RefreshPolicy(mode: .interval, seconds: 12, event: "refresh"))
    #expect(item.command?.interval == nil)
    #expect(item.command?.event == nil)
  }

  @Test("Selected displays need IDs and interval refresh needs seconds")
  func validation() {
    var config = BarConfiguration.default
    config.bar.displays = .selected
    #expect(throws: (any Error).self) { try config.validate() }
    config.bar.displayIDs = [1]
    config.items.right[1].refresh = RefreshPolicy(mode: .interval)
    #expect(throws: (any Error).self) { try config.validate() }
  }

  @MainActor @Test("Manual clock snapshots remain stable until explicitly triggered")
  func manualClock() async throws {
    let providers = ProviderRuntime()
    var config = BarConfiguration.default
    config.items.left = []
    config.items.right = [.init(id: "clock", type: .clock, refresh: .init(mode: .manual))]
    providers.configure(config)
    defer { providers.stop() }
    let initial = providers.dates["clock"]
    try await Task.sleep(for: .milliseconds(30))
    #expect(providers.dates["clock"] == initial)
    providers.trigger("clock")
    #expect(try #require(providers.dates["clock"]) > #require(initial))
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

  @MainActor @Test("Explicit clock formats stay 24-hour and path expansion is single-pass")
  func formatting() {
    let date = Date(timeIntervalSince1970: 13 * 3600 + 5 * 60 + 9)
    #expect(
      ClockFormatter.string(date, format: "HH:mm:ss", timeZone: TimeZone(secondsFromGMT: 0)!)
        == "13:05:09"
    )
    #expect(
      ActionRunner.expand("${ROOT}/tool", environment: ["ROOT": "${OTHER}", "OTHER": "/tmp"])
        == "${OTHER}/tool"
    )
  }

}
