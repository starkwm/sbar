import Foundation

struct ShellCommand: Codable, Equatable, Sendable {
  var script: String
  var timeout: Double?
}
