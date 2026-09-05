import Foundation

struct Plugin: Codable, Equatable, Sendable {
  var executable: String
  var arguments: [String]?
  var restart: Bool?
}
