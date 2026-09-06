import Foundation

typealias PluginOutput = CommandValue

struct PluginInput: Codable, Sendable {
  var version = 1
  let event: String
  let value: JSONValue?
}
