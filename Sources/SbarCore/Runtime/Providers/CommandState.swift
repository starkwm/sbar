import Foundation

struct CommandState: Equatable, Sendable {
  enum Status: String, Sendable { case running, success, failure }

  static func decode(_ output: String, configuration: ShellCommand) throws -> CommandValue {
    guard configuration.format == .json else { return CommandValue(text: output) }
    let value = try JSONDecoder().decode(CommandValue.self, from: Data(output.utf8))
    try ItemStyle.validateColor(value.tint, path: "command result.tint")
    if case .system(let name) = value.symbol,
      name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      throw ConfigurationError.invalidValue(
        path: "command result.symbol",
        reason: "Must not be blank."
      )
    }
    return value
  }

  static func displayText(_ text: String, limit: Int) -> String {
    let singleLine = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    guard singleLine.count > limit else { return singleLine }
    return String(singleLine.prefix(max(0, limit - 1))) + "…"
  }

  var status: Status = .running
  var lastSuccess: CommandValue?
  var error: String?

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.command
    let retaining = status != .failure || settings?.onError == .keepLast
    let value = retaining ? lastSuccess : nil
    let text = value?.text ?? (status == .running ? "…" : error ?? "Command failed")
    let symbol: WidgetSymbol?
    let tint: String?
    switch status {
    case .running:
      symbol = settings?.symbols?.running
      tint = settings?.tints?.running
    case .success:
      symbol = settings?.symbols?.success
      tint = settings?.tints?.success
    case .failure:
      symbol = settings?.symbols?.failure
      tint = settings?.tints?.failure
    }
    let displayed = Self.displayText(text, limit: settings?.maxLength ?? 256)
    return WidgetPresentation(
      text: settings?.showValue == false ? "" : displayed,
      symbol: settings?.showSymbol == false
        ? nil : item.symbol ?? settings?.symbols?.resolve(symbol) ?? value?.symbol,
      tint: tint ?? value?.tint,
      hidden: (status == .failure && settings?.onError == .hide) || value?.hidden == true,
      accessibilityLabel: displayed,
      tooltipValues: [
        "output": value?.text ?? "",
        "status": status.rawValue,
        "error": error ?? "",
      ]
    )
  }
}

struct CommandValue: Codable, Equatable, Sendable {
  var text: String
  var symbol: ItemSymbol?
  var tint: String?
  var hidden: Bool?
}
