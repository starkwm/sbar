import SwiftUI

struct AgentActivityPopup: View {
  let item: Item

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      content(now: context.date)
    }
  }

  @Environment(ProviderRuntime.self) private var providers

  private var state: AgentActivityState {
    guard case .agentActivity(let state) = providers.widgetStates[.agentActivity] else {
      return AgentActivityState()
    }
    return state.selected(item.agentActivity ?? AgentActivityConfiguration())
  }

  private func content(now: Date) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(state.entries) { entry in
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text(
                [entry.report.host, entry.report.agent ?? entry.report.source].compactMap { $0 }
                  .joined(separator: " · ")
              ).font(.headline)
              if let title = entry.report.title { Text(title) }
              if let project = entry.report.project { Text(project).font(.caption) }
              Text(
                "\(entry.state.label) · \(Int(max(0, now.timeIntervalSince(entry.startedAt))))s elapsed"
              )
              Text("Last reported \(entry.reportedAt, style: .relative) ago").font(.caption)
              if now.timeIntervalSince(entry.reportedAt)
                > (item.agentActivity?.staleAfter ?? 300)
              {
                Text("Stale report; current activity is unconfirmed").font(.caption)
              }
            }
            Spacer()
            Button("Dismiss") {
              providers.agents.dismiss(source: entry.report.source, session: entry.report.session)
              providers.publishAgents()
            }
          }
          .textSelection(.enabled)
        }
        if state.entries.isEmpty { Text("No agent activity") }
      }
    }
    .frame(minWidth: 320, maxHeight: 420)
  }
}
