import Foundation
import Testing

@testable import SbarCore

@Suite("ConfigurationPath")
struct ConfigurationPathTests {
  @Test("default discovery prefers JSONC and falls back to JSON")
  func defaultDiscovery() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let json = directory.appending(path: "config.json")
    let jsonc = directory.appending(path: "config.jsonc")

    #expect(ConfigurationPath.defaultURL(directory: directory) == json)
    try Data("{}".utf8).write(to: json)
    #expect(ConfigurationPath.defaultURL(directory: directory) == json)
    try Data("/* invalid".utf8).write(to: jsonc)
    #expect(ConfigurationPath.defaultURL(directory: directory) == jsonc)
    try FileManager.default.removeItem(at: json)
    #expect(ConfigurationPath.defaultURL(directory: directory) == jsonc)
  }
}
