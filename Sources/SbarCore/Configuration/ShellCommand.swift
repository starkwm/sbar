import Foundation

struct ShellCommand: Codable, Equatable, Sendable {
  var script: String
  var timeout: Double?
  var output: CommandOutput?
  var format: CommandFormat?
  var maxLength: Int?
  var onError: CommandErrorBehavior?
  var symbols: CommandSymbols?
  var tints: CommandTints?
  var showSymbol: Bool?

  func validate(path: String) throws {
    guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw ConfigurationError.invalidValue(path: path + ".script", reason: "Must not be blank.")
    }
    try ItemStyle.validateNumber(timeout, range: 0.1...60, path: path + ".timeout")
    if let maxLength, !(1...4096).contains(maxLength) {
      throw ConfigurationError.invalidValue(
        path: path + ".maxLength",
        reason: "Must be between 1 and 4096."
      )
    }
    if format == .json && output == .combined {
      throw ConfigurationError.invalidValue(
        path: path + ".output",
        reason: "JSON output requires stdout."
      )
    }
    try symbols?.validate(path: path + ".symbols")
    try tints?.validate(path: path + ".tints")
  }

  func sameExecution(as other: Self?) -> Bool {
    guard let other else { return false }
    return script == other.script && timeout == other.timeout && output == other.output
      && format == other.format
  }
}

enum CommandOutput: String, Codable, Sendable { case stdout, combined }
enum CommandFormat: String, Codable, Sendable { case text, json }
enum CommandErrorBehavior: String, Codable, Sendable { case show, keepLast, hide }

struct CommandSymbols: Codable, Equatable, Sendable {
  var font: String?
  var size: Double?
  var running: WidgetSymbol?
  var success: WidgetSymbol?
  var failure: WidgetSymbol?

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)
    try running?.validate(font: font, path: "\(path).running")
    try success?.validate(font: font, path: "\(path).success")
    try failure?.validate(font: font, path: "\(path).failure")
  }

  func resolve(_ symbol: WidgetSymbol?) -> ItemSymbol? {
    symbol?.resolve(font: font, size: size)
  }
}

struct CommandTints: Codable, Equatable, Sendable {
  var running: String?
  var success: String?
  var failure: String?

  func validate(path: String) throws {
    for (key, tint) in [("running", running), ("success", success), ("failure", failure)] {
      try ItemStyle.validateColor(tint, path: "\(path).\(key)")
    }
  }
}
