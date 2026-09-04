import Foundation
import Testing
@testable import StarkBar

@MainActor
@Suite("Configuration loading and observation")
struct ConfigurationStoreTests {
    @Test("Invalid reload retains valid configuration and reports the coding path")
    func invalidReload() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "config.json")
        let store = ConfigurationStore(configurationURL: url)
        try write(height: 48, to: url)
        store.load()
        #expect(store.configuration.bar.height == 48)
        try Data(#"{"schemaVersion":1,"bar":{},"items":{"right":[{"id":"clock","type":42}]}}"#.utf8).write(to: url)
        store.load()
        #expect(store.configuration.bar.height == 48)
        #expect(store.errorMessage?.hasPrefix("items.right[0].type:") == true)
        try write(height: 40, to: url)
        store.load()
        #expect(store.configuration.bar.height == 40)
        #expect(store.errorMessage == nil)
    }

    @Test("Missing configuration loads defaults without an error")
    func missingFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(configurationURL: directory.appending(path: "missing.json"))
        store.load()
        #expect(store.configuration == .default)
        #expect(store.errorMessage == nil)
    }

    @Test("Only changed valid configurations notify the renderer")
    func notifications() throws {
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

    @Test("Observation survives atomic replacement, direct edits, deletion and recreation")
    func fileChanges() async throws {
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

    @Test("Observation finds a configuration created inside initially missing directories")
    func firstCreation() async throws {
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

    @Test("Stopping cancels pending reloads and observation can restart")
    func stopAndRestart() async throws {
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
        let configuration = BarConfiguration(schemaVersion: BarConfiguration.currentSchemaVersion, bar: .init(height: height), items: .init())
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
