import Foundation

struct PomodoroSymbols: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case font, size, focus, shortBreak, longBreak, paused
  }

  var font: String?
  var size: Double?
  var focus: WidgetSymbol?
  var shortBreak: WidgetSymbol?
  var longBreak: WidgetSymbol?
  var paused: WidgetSymbol?

  init(from decoder: any Decoder) throws {
    let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
    guard Set(values.keys).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue))) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown pomodoro symbol key.")
      )
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    font = try container.decodeIfPresent(String.self, forKey: .font)
    size = try container.decodeIfPresent(Double.self, forKey: .size)
    focus = try container.decodeIfPresent(WidgetSymbol.self, forKey: .focus)
    shortBreak = try container.decodeIfPresent(WidgetSymbol.self, forKey: .shortBreak)
    longBreak = try container.decodeIfPresent(WidgetSymbol.self, forKey: .longBreak)
    paused = try container.decodeIfPresent(WidgetSymbol.self, forKey: .paused)
  }

  func validate(path: String) throws {
    try WidgetSymbol.validateDefaults(font: font, size: size, path: path)
    for (key, value) in [
      ("focus", focus), ("shortBreak", shortBreak), ("longBreak", longBreak), ("paused", paused),
    ] {
      try value?.validate(font: font, path: "\(path).\(key)")
    }
  }

  func resolve(phase: PomodoroPhase, status: PomodoroStatus) -> ItemSymbol? {
    if status == .paused, let paused { return paused.resolve(font: font, size: size) }
    let value =
      switch phase {
      case .focus: focus
      case .shortBreak: shortBreak
      case .longBreak: longBreak
      }
    return value?.resolve(font: font, size: size)
  }
}
