import Foundation

enum AgentActivityStatus: String, Codable, CaseIterable, Sendable {
  case working, needsInput, idle, finished, failed, interrupted, unknown

  var label: String { self == .needsInput ? "needs input" : rawValue }
}

struct AgentActivityReport: Codable, Equatable, Sendable {
  var version: Int = 1
  var source: String
  var session: String
  var run: String
  var sequence: Int
  var state: AgentActivityStatus
  var replaces: String?
  var title: String?
  var project: String?
  var host: String?
  var agent: String?
  var identity: String?
  var heartbeatSeconds: Double?
}

struct AgentActivityEntry: Codable, Equatable, Sendable, Identifiable {
  var report: AgentActivityReport
  var startedAt: Date
  var reportedAt: Date
  var changedAt: Date
  var expired = false
  var dismissed = false
  var id: String { report.source + ":" + report.session }
  var state: AgentActivityStatus { expired ? .unknown : report.state }
}

@MainActor
final class AgentActivityStore {
  private(set) var entries: [String: AgentActivityEntry] = [:]
  private var accepted: [String: AgentActivityReport] = [:]
  private var retired: [String: [String]] = [:]

  func report(_ report: AgentActivityReport, now: Date = Date()) throws {
    let strings = [report.source, report.session, report.run]
    guard report.version == 1, report.sequence >= 0,
      strings.allSatisfy({
        !$0.isEmpty && $0.utf8.count <= 256 && !$0.contains(":")
          && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
      }),
      [report.title, report.project, report.host, report.agent, report.identity].compactMap({ $0 })
        .allSatisfy({
          $0.utf8.count <= 1024
            && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        }),
      report.heartbeatSeconds.map({ $0.isFinite && (1...3600).contains($0) }) ?? true
    else {
      throw MessageError.message("Invalid version, identity, sequence, metadata or heartbeat.")
    }
    let key = report.source + ":" + report.session
    let old = entries[key]
    guard retired[key]?.contains(report.run) != true else {
      throw MessageError.message("Run has been superseded.")
    }
    if let old {
      if old.report.run == report.run {
        if report.sequence < old.report.sequence {
          throw MessageError.message("Out-of-order report.")
        }
        if report.sequence == old.report.sequence {
          guard report == accepted[key] else {
            throw MessageError.message("Conflicting duplicate report.")
          }
          return
        }
      } else {
        guard report.replaces == old.report.run else {
          throw MessageError.message("New run must name the current run in replaces.")
        }
        retired[key] = (retired[key, default: []] + [old.report.run]).suffix(32)
      }
    } else if report.replaces != nil {
      throw MessageError.message("No current run. Republish without replaces after restart.")
    }
    if old == nil, entries.count >= 4096,
      let oldest = entries.values.min(by: { $0.reportedAt < $1.reportedAt })?.id
    {
      // Evict the least recently reported session instead of rejecting new ones.
      entries[oldest] = nil
      accepted[oldest] = nil
      retired[oldest] = nil
    }
    accepted[key] = report
    var next = report
    next.title = next.title ?? old?.report.title
    next.project = next.project ?? old?.report.project
    next.host = next.host ?? old?.report.host
    next.agent = next.agent ?? old?.report.agent
    next.identity = next.identity ?? old?.report.identity
    entries[key] = AgentActivityEntry(
      report: next,
      startedAt: old?.report.run == report.run ? old!.startedAt : now,
      reportedAt: now,
      changedAt: old?.report.run == report.run && old?.report.state == report.state
        ? old!.changedAt : now,
      dismissed: old?.report.run == report.run && old?.report.state == report.state
        ? old!.dismissed : false
    )
  }

  func dismiss(source: String, session: String) {
    entries[source + ":" + session]?.dismissed = true
  }

  func snapshot(now: Date = Date()) -> AgentActivityState {
    for key in entries.keys {
      if let entry = entries[key], let heartbeat = entry.report.heartbeatSeconds,
        now.timeIntervalSince(entry.reportedAt) > heartbeat
      {
        entries[key]?.expired = true
      }
    }
    let visible = entries.values.filter { !$0.dismissed }
    // A host report suppresses only an explicitly correlated standalone identity.
    let hosted = Set(
      visible.filter { $0.report.host != nil }.compactMap { $0.report.identity }.filter {
        !$0.isEmpty
      }
    )
    return AgentActivityState(
      entries: visible.filter {
        $0.report.host != nil || $0.report.identity.map { !hosted.contains($0) } ?? true
      }.sorted { $0.id < $1.id },
      now: now
    )
  }

  func clear() {
    entries = [:]
    retired = [:]
    accepted = [:]
  }
}
