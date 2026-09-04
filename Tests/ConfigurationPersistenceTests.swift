import Foundation
import Testing
@testable import StarkBar

@MainActor
@Suite("Configuration persistence")
struct ConfigurationPersistenceTests {
    @Test("First save creates directories, config and a linked schema")
    func firstSave() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(configurationURL: directory.appending(path: "nested/config.json"))
        try store.save(.default)
        let data = try Data(contentsOf: store.configurationURL)
        #expect(try JSONDecoder().decode(BarConfiguration.self, from: data) == .default)
        let document = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(document["$schema"] as? String == "config.schema.json")
        let schemaURL = store.configurationURL.deletingLastPathComponent().appending(path: "config.schema.json")
        #expect(try Data(contentsOf: schemaURL) == ConfigurationSchema.data())
        #expect(!FileManager.default.fileExists(atPath: store.backupURL.path))
    }

    @Test("Save preserves exact previous bytes, even invalid JSON, and rotates one backup")
    func backup() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(configurationURL: directory.appending(path: "config.json"))
        let original = Data("{ invalid external edit\n".utf8)
        try original.write(to: store.configurationURL)
        try store.save(.default)
        #expect(try Data(contentsOf: store.backupURL) == original)
        let firstSave = try Data(contentsOf: store.configurationURL)
        var candidate = BarConfiguration.default
        candidate.bar.height = 48
        try store.save(candidate)
        #expect(try Data(contentsOf: store.backupURL) == firstSave)
        #expect(store.configuration == candidate)
        #expect(store.errorMessage == nil)
    }

    @Test("Invalid candidates leave configuration and backup untouched")
    func invalidSave() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(configurationURL: directory.appending(path: "config.json"))
        try store.save(.default)
        let original = try Data(contentsOf: store.configurationURL)
        var candidate = BarConfiguration.default
        candidate.bar.height = 1
        #expect(throws: ConfigurationError.invalidBarHeight(1)) { try store.save(candidate) }
        #expect(try Data(contentsOf: store.configurationURL) == original)
        #expect(!FileManager.default.fileExists(atPath: store.backupURL.path))
        #expect(store.configuration == .default)
        #expect(store.errorMessage?.hasPrefix("bar.height:") == true)
    }

    @Test("Backup failure prevents replacement and publication")
    func backupFailure() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(configurationURL: directory.appending(path: "config.json"))
        try store.save(.default)
        let original = try Data(contentsOf: store.configurationURL)
        try FileManager.default.createDirectory(at: store.backupURL, withIntermediateDirectories: false)
        var candidate = BarConfiguration.default
        candidate.bar.height = 48
        #expect(throws: (any Error).self) { try store.save(candidate) }
        #expect(try Data(contentsOf: store.configurationURL) == original)
        #expect(store.configuration == .default)
        #expect(store.errorMessage != nil)
    }

    @Test("Successful saves notify once and reload does not notify again")
    func publication() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(configurationURL: directory.appending(path: "config.json"))
        var notifications = 0
        store.configurationDidChange = { notifications += 1 }
        var candidate = BarConfiguration.default
        candidate.bar.height = 48
        try store.save(candidate)
        store.load()
        #expect(notifications == 1)
    }

    @Test("Bundled schema matches the supported version and item types")
    func schema() throws {
        let schema = try #require(JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any])
        let properties = try #require(schema["properties"] as? [String: Any])
        let version = try #require(properties["schemaVersion"] as? [String: Any])
        #expect(version["const"] as? Int == BarConfiguration.currentSchemaVersion)
        let definitions = try #require(schema["$defs"] as? [String: Any])
        let item = try #require(definitions["item"] as? [String: Any])
        let itemProperties = try #require(item["properties"] as? [String: Any])
        let type = try #require(itemProperties["type"] as? [String: Any])
        let types = try #require(type["enum"] as? [String])
        #expect(Set(types) == Set(ItemType.allCases.map(\.rawValue)))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
