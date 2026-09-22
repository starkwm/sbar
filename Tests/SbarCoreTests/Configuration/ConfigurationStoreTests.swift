import Foundation
import Testing

@testable import SbarCore

@MainActor
@Suite("ConfigurationStore")
struct ConfigurationStoreTests {
  @Test("configurationDidChange: notifies only for changed valid configurations")
  func changeNotifications() throws {
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
    #expect(store.errorMessage != nil)

    try write(height: 40, to: url)
    store.load()

    #expect(updates == 1)
    #expect(store.errorMessage == nil)

    try write(height: 48, to: url)
    store.load()

    #expect(updates == 2)
    #expect(store.configuration.bar.height == 48)
  }

  @Test(
    "startObserving: observation loads immediately, stops updates, and reloads after restarting"
  )
  func observationLifecycle() async throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.json")
    try write(height: 40, to: url)

    let store = ConfigurationStore(configurationURL: url)
    store.startObserving()
    defer { store.stopObserving() }

    #expect(store.configuration.bar.height == 40)

    try write(height: 48, to: url)
    store.stopObserving()
    try await Task.sleep(for: .milliseconds(200))

    #expect(store.configuration.bar.height == 40)

    store.startObserving()

    #expect(store.configuration.bar.height == 48)

    try write(height: 56, to: url)
    try await waitUntil { store.configuration.bar.height == 56 }
  }

  @Test("load: retains valid configuration and reports the coding path after an invalid reload")
  func invalidReload() throws {
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
  func missingFile() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigurationStore(configurationURL: directory.appending(path: "missing.json"))

    store.load()

    #expect(store.configuration == .default)
    #expect(store.errorMessage == nil)
  }

  @Test(
    "load: JSONC loads, validates, and retains the last valid configuration",
    arguments: ["json", "jsonc"]
  )
  func loadsJSONC(extension suffix: String) throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.\(suffix)")
    let original = Data(
      "{ // Settings\n \"schemaVersion\":1,\"bar\":{\"height\":48,},\"items\":{},}".utf8
    )
    try original.write(to: url)
    let store = ConfigurationStore(configurationURL: url)
    store.load()

    #expect(store.configuration.bar.height == 48)
    #expect(store.errorMessage == nil)

    try ConfigurationValidator.validate(url: url)

    #expect(try Data(contentsOf: url) == original)

    try Data("/* unfinished".utf8).write(to: url)
    store.load()

    #expect(store.configuration.bar.height == 48)
    #expect(store.errorMessage?.contains("Unterminated block comment") == true)
    #expect(throws: (any Error).self) { try ConfigurationValidator.validate(url: url) }

    try Data("{\"schemaVersion\":1,\"bar\":{\"height\":52,},\"items\":{},}".utf8).write(to: url)
    store.load()

    #expect(store.configuration.bar.height == 52)
    #expect(store.errorMessage == nil)
  }

  @Test("ConfigurationValidator.validate: reports errors without writing the file")
  func validation() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "config.json")

    #expect(throws: (any Error).self) { try ConfigurationValidator.validate(url: url) }

    try write(height: 48, to: url)
    let original = try Data(contentsOf: url)

    try ConfigurationValidator.validate(url: url)

    #expect(try Data(contentsOf: url) == original)

    try write(height: 1, to: url)

    #expect(throws: (any Error).self) { try ConfigurationValidator.validate(url: url) }

    try Data(
      #"{"schemaVersion": 1, "bar": {}, "items": {"right": [{"id": "clock", "type": 42}]}}"#.utf8
    ).write(to: url)

    do {
      try ConfigurationValidator.validate(url: url)
      Issue.record("Invalid configuration passed validation")
    } catch {
      #expect(error.localizedDescription.hasPrefix("items.right[0].type:"))
    }
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    return url
  }

  private func write(height: Double, to url: URL) throws {
    let configuration = Configuration(
      schemaVersion: Configuration.currentSchemaVersion,
      bar: .init(height: height),
      items: .init()
    )

    try JSONEncoder().encode(configuration).write(to: url, options: .atomic)
  }
}
