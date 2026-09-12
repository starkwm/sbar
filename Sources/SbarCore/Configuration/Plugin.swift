import Foundation

struct Plugin: Codable, Equatable, Sendable {
  var executable: String
  var arguments: [String]?
  var restart: Bool?
  var maxLength: Int?
  var onError: CommandErrorBehavior?
  var symbols: CommandSymbols?
  var tints: CommandTints?
  var showSymbol: Bool?

  func validate(path: String) throws {
    guard !executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ConfigurationError.invalidValue(
        path: path + ".executable",
        reason: "Must not be blank."
      )
    }
    if let maxLength, !(1...4096).contains(maxLength) {
      throw ConfigurationError.invalidValue(
        path: path + ".maxLength",
        reason: "Must be between 1 and 4096."
      )
    }
    try symbols?.validate(path: path + ".symbols")
    try tints?.validate(path: path + ".tints")
  }

  func sameExecution(as other: Self?) -> Bool {
    guard let other else { return false }
    return executable == other.executable && arguments == other.arguments
      && restart == other.restart
  }
}
