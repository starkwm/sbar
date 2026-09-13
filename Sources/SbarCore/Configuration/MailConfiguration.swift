import Foundation

struct MailConfiguration: Codable, Equatable, Sendable {
  var pollInterval: Double?

  var resolvedPollInterval: Double { pollInterval ?? 30 }

  func validate(path: String) throws {
    guard let pollInterval else { return }
    guard pollInterval.isFinite, pollInterval >= 5 else {
      throw ConfigurationError.invalidValue(
        path: "\(path).pollInterval",
        reason: "Must be a finite number of at least 5 seconds."
      )
    }
  }
}
