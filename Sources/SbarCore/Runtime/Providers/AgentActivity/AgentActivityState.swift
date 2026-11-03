import Foundation

struct AgentActivityState: Equatable, Sendable {
  static let priority: [AgentActivityStatus] = [
    .needsInput, .failed, .interrupted, .working, .unknown, .idle, .finished,
  ]
  var entries: [AgentActivityEntry] = []
  var now = Date()
  var status: AgentActivityStatus {
    Self.priority.first { state in entries.contains { $0.state == state } } ?? .unknown
  }
  var text: String {
    let parts = Self.priority.compactMap { state -> String? in
      let count = entries.filter { $0.state == state }.count
      return count == 0 ? nil : "\(count) \(state.label)"
    }
    return parts.isEmpty ? "No agent activity" : parts.joined(separator: " · ")
  }

  var textEntries: [[String: String]] {
    entries.map { entry in
      [
        "source": entry.report.source, "session": entry.report.session, "run": entry.report.run,
        "agent": entry.report.agent ?? entry.report.source, "host": entry.report.host ?? "",
        "title": entry.report.title ?? "", "project": entry.report.project ?? "",
        "status": entry.state.rawValue,
        "elapsed": String(Int(now.timeIntervalSince(entry.startedAt))),
        "lastReported": entry.reportedAt.ISO8601Format(),
      ]
    }
  }

  func selected(_ settings: AgentActivityConfiguration) -> Self {
    Self(
      entries: entries.filter { entry in
        (settings.sources.map { $0.contains(entry.report.source) } ?? true)
          && (settings.projects.map { $0.contains(entry.report.project ?? "") } ?? true)
          && !(entry.state == .finished
            && now.timeIntervalSince(entry.changedAt) >= (settings.finishedRetention ?? 30))
      },
      now: now
    )
  }

  func selected(anyOf settings: [AgentActivityConfiguration]) -> Self {
    let ids = Set(settings.flatMap { selected($0).entries.map(\.id) })
    return Self(entries: entries.filter { ids.contains($0.id) }, now: now)
  }

  func values() -> [String: String] {
    var values = ["total": String(entries.count), "status": status.rawValue]
    for state in AgentActivityStatus.allCases {
      values[state.rawValue] = String(entries.filter { $0.state == state }.count)
    }
    return values
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.agentActivity ?? AgentActivityConfiguration()
    let state = selected(settings)
    let symbols: [AgentActivityStatus: String] = [
      .working: "gearshape.2", .needsInput: "questionmark.bubble", .idle: "moon.zzz",
      .finished: "checkmark.bubble",
      .failed: "exclamationmark.triangle", .interrupted: "pause.circle",
      .unknown: "questionmark.circle",
    ]
    return WidgetPresentation(
      text: state.text,
      symbol: settings.showSymbol == false
        ? nil
        : item.symbol ?? settings.symbols?[state.status.rawValue]?.resolve(
          font: settings.font,
          size: settings.size
        ) ?? .system(symbols[state.status]!),
      tint: settings.tints?[state.status.rawValue]
        ?? (state.status == .needsInput ? "#FFCC00" : state.status == .failed ? "#FF5555" : nil),
      hidden: state.entries.isEmpty && settings.hideWhenEmpty != false,
      accessibilityLabel: state.text
    )
  }
}
