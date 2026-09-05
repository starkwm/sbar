import Foundation

struct ItemAction: Codable, Equatable, Sendable {
  enum Kind: String, Codable, CaseIterable, Sendable { case command, url, application }

  var kind: Kind
  var value: String
}

struct ShellCommandConfiguration: Codable, Equatable, Sendable {
  var script: String
  var interval: Double?
  var timeout: Double?
  var event: String?
}
