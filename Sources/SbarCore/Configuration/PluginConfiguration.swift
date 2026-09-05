import Foundation

struct PluginConfiguration: Codable, Equatable, Sendable {
  var executable: String
  var arguments: [String]?
  var restart: Bool?
}
