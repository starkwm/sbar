import Foundation

struct ShellCommandConfiguration: Codable, Equatable, Sendable {
  var script: String
  var timeout: Double?
}
