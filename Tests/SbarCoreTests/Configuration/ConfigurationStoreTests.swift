import Foundation
import Testing

@testable import SbarCore

@MainActor
@Suite("ConfigurationStore")
struct ConfigurationStoreTests {
  @Test("load: retains valid configuration and reports the coding path after an invalid reload")
  func loadRetainsConfigurationAfterInvalidReload() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.json")
    let store = ConfigurationStore(configurationURL: url)

    try write(height: 48, to: url)
    store.load()

    #expect(store.configuration.bar.height == 48)

    try Data(#"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"clock","type":42}]}}"#.utf8)
      .write(to: url)
    store.load()

    #expect(store.configuration.bar.height == 48)
    #expect(store.errorMessage?.hasPrefix("items.right[0].type:") == true)

    try write(height: 40, to: url)
    store.load()

    #expect(store.configuration.bar.height == 40)
    #expect(store.errorMessage == nil)
  }

  @Test("load: uses defaults when the configuration file is missing")
  func loadUsesDefaultsWhenFileIsMissing() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigurationStore(configurationURL: directory.appending(path: "missing.json"))

    store.load()

    #expect(store.configuration == .default)
    #expect(store.errorMessage == nil)
  }

  @Test("ConfigurationValidation.validate: reports errors without writing the file")
  func validateReportsErrorsWithoutWritingFile() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.json")

    #expect(throws: (any Error).self) { try ConfigurationValidation.validate(url: url) }

    try write(height: 48, to: url)
    let original = try Data(contentsOf: url)

    try ConfigurationValidation.validate(url: url)

    #expect(try Data(contentsOf: url) == original)

    try write(height: 1, to: url)
    #expect(throws: (any Error).self) { try ConfigurationValidation.validate(url: url) }

    try Data(
      #"{"schemaVersion": 1, "bar": {}, "items": {"right": [{"id": "clock", "type": 42}]}}"#.utf8
    ).write(to: url)
    do {
      try ConfigurationValidation.validate(url: url)
      Issue.record("Invalid configuration passed validation")
    } catch {
      #expect(error.localizedDescription.hasPrefix("items.right[0].type:"))
    }
  }

  @Test("configurationDidChange: notifies only for changed valid configurations")
  func configurationDidChangeNotifiesOnlyForValidChanges() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.json")
    let store = ConfigurationStore(configurationURL: url)
    var updates = 0
    store.configurationDidChange = { updates += 1 }

    try write(height: 40, to: url)
    store.load()
    store.load()

    try Data("{".utf8).write(to: url)
    store.load()

    #expect(updates == 1)
  }

  @Test("startObserving: handles replacement, edits, deletion, and recreation")
  func startObservingHandlesFileChanges() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.json")
    try write(height: 40, to: url)

    let store = ConfigurationStore(configurationURL: url)
    store.startObserving()
    defer { store.stopObserving() }

    try write(height: 48, to: url)
    try await wait { store.configuration.bar.height == 48 }

    try write(height: 52, to: url, atomic: false)
    try await wait { store.configuration.bar.height == 52 }

    try FileManager.default.removeItem(at: url)
    try await wait { store.configuration == .default }

    try write(height: 60, to: url)
    try await wait { store.configuration.bar.height == 60 }
  }

  @Test("startObserving: finds files created inside initially missing directories")
  func startObservingFindsFilesInNewDirectories() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let parent = directory.appending(path: "nested/starkbar")
    let url = parent.appending(path: "config.json")
    let store = ConfigurationStore(configurationURL: url)
    store.startObserving()
    defer { store.stopObserving() }

    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    try write(height: 56, to: url)
    try await wait { store.configuration.bar.height == 56 }
  }

  @Test("stopObserving: cancels pending reloads and allows observation to restart")
  func stopObservingCancelsReloadsAndAllowsRestart() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.json")
    try write(height: 40, to: url)

    let store = ConfigurationStore(configurationURL: url)
    store.startObserving()
    defer { store.stopObserving() }

    try write(height: 48, to: url)
    store.stopObserving()
    try await Task.sleep(for: .milliseconds(200))

    #expect(store.configuration.bar.height == 40)

    store.startObserving()
    #expect(store.configuration.bar.height == 48)

    try write(height: 56, to: url)
    try await wait { store.configuration.bar.height == 56 }
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    return url
  }

  private func write(height: Double, to url: URL, atomic: Bool = true) throws {
    let configuration = BarConfiguration(
      schemaVersion: BarConfiguration.currentSchemaVersion,
      bar: .init(height: height),
      items: .init()
    )

    try JSONEncoder().encode(configuration).write(to: url, options: atomic ? .atomic : [])
  }

  private func wait(until condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))

    while !condition(), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(20))
    }

    #expect(condition(), "Configuration did not reload before the deadline")
  }
}
