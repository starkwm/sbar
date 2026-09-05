import Foundation

struct ShellCommandConfiguration: Codable, Equatable, Sendable {
  var script: String
  var interval: Double?
  var timeout: Double?
  var event: String?
}
