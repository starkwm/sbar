import Foundation

struct PluginOutput: Codable, Equatable, Sendable {
  let text: String
}

struct PluginInput: Codable, Sendable {
  var version = 1
  let event: String
  let value: JSONValue?
}
