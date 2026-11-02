import Foundation

struct RemindersState: Codable, Equatable, Sendable {
  private static func date(_ components: DateComponents, allDay: Bool, timeZone: TimeZone) -> Date?
  {
    guard let year = components.year, let month = components.month, let day = components.day else {
      return nil
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = allDay ? timeZone : components.timeZone ?? timeZone
    let fields = DateComponents(
      year: year,
      month: month,
      day: day,
      hour: allDay ? 0 : components.hour ?? 0,
      minute: allDay ? 0 : components.minute ?? 0,
      second: allDay ? 0 : components.second ?? 0
    )
    guard fields.isValidDate(in: calendar) else { return nil }
    return calendar.date(from: fields)
  }

  var access: RemindersStatus = .loading
  var lists: [ReminderList] = []
  var reminders: [ReminderRecord] = []
  var now = Date()
  var timeZone = TimeZone.current
  var error = ""

  var text: String { textValues(settings: nil)["value"] ?? "Reminders unavailable" }

  func selection(settings: RemindersConfiguration?) -> ReminderSelection {
    guard access == .empty else { return ReminderSelection(status: access, error: error) }
    let ids = settings?.listIds.map(Set.init)
    if let ids, !ids.isSubset(of: Set(lists.map(\.id))) {
      return ReminderSelection(
        status: .unavailable,
        error: "A selected Reminders list is missing. Rediscover list IDs."
      )
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let today = calendar.startOfDay(for: now)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    let horizon = calendar.date(
      byAdding: .day,
      value: (settings?.resolvedLookaheadDays ?? 7) + 1,
      to: today
    )!
    var entries: [SelectedReminder] = []
    var seen = Set<String>()
    for record in reminders where !record.completed && (ids == nil || ids!.contains(record.listId))
    {
      guard seen.insert(record.id).inserted else { continue }
      guard let components = record.due else {
        if settings?.includeUndated == true {
          entries.append(SelectedReminder(record: record, status: .undated))
        }
        continue
      }
      let allDay = components.hour == nil && components.minute == nil && components.second == nil
      guard let date = Self.date(components, allDay: allDay, timeZone: timeZone) else {
        return ReminderSelection(status: .unavailable, error: "A reminder has an invalid due date.")
      }
      let status: RemindersStatus
      if allDay ? date < today : date < now {
        status = .overdue
      } else if date < tomorrow {
        status = .dueToday
      } else if date < horizon {
        status = .upcoming
      } else {
        continue
      }
      entries.append(SelectedReminder(record: record, status: status, date: date, allDay: allDay))
    }
    entries.sort {
      if $0.status.rank != $1.status.rank { return $0.status.rank < $1.status.rank }
      let leftDay = $0.date.map { calendar.startOfDay(for: $0) } ?? .distantFuture
      let rightDay = $1.date.map { calendar.startOfDay(for: $0) } ?? .distantFuture
      if leftDay != rightDay { return leftDay < rightDay }
      if $0.allDay != $1.allDay { return !$0.allDay }
      if $0.date != $1.date { return ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
      return ($0.record.displayTitle, $0.record.listId, $0.record.id)
        < ($1.record.displayTitle, $1.record.listId, $1.record.id)
    }
    return ReminderSelection(status: entries.first?.status ?? .empty, entries: entries)
  }

  func textValues(settings: RemindersConfiguration?) -> [String: String] {
    let selected = selection(settings: settings)
    let available = selected.status.available
    var values = Dictionary(
      uniqueKeysWithValues: [
        "total", "dueTodayCount", "overdueCount", "upcomingCount", "undatedCount",
        "title", "list", "listId", "dueDate", "dueTime", "due", "nextStatus",
      ].map { ($0, "") }
    )
    values.merge([
      "status": selected.status.rawValue, "available": String(available),
      "hasNext": String(!selected.entries.isEmpty), "hasDueDate": "false", "allDay": "false",
      "error": selected.error, "value": selected.label,
    ]) { _, new in new }
    if available {
      values["total"] = String(selected.entries.count)
      for (key, status) in [
        ("dueTodayCount", RemindersStatus.dueToday), ("overdueCount", .overdue),
        ("upcomingCount", .upcoming), ("undatedCount", .undated),
      ] { values[key] = String(selected.count(status)) }
    }
    guard let next = selected.entries.first else { return values }
    values["title"] = next.record.displayTitle
    values["list"] = lists.first { $0.id == next.record.listId }?.title ?? ""
    values["listId"] = next.record.listId
    values["nextStatus"] = next.status.rawValue
    values["allDay"] = String(next.allDay)
    values["hasDueDate"] = String(next.date != nil)
    if let date = next.date {
      let formatter = DateFormatter()
      formatter.timeZone = timeZone
      formatter.dateStyle = .medium
      values["dueDate"] = formatter.string(from: date)
      if !next.allDay {
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if let format = settings?.timeFormat { formatter.dateFormat = format }
        values["dueTime"] = formatter.string(from: date)
      }
      values["due"] = [values["dueDate"]!, values["dueTime"]!].filter { !$0.isEmpty }.joined(
        separator: " "
      )
    } else {
      values["due"] = "No due date"
    }
    return values
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.reminders ?? RemindersConfiguration()
    let values = textValues(settings: settings)
    let status = RemindersStatus(rawValue: values["status"]!)!
    var label =
      status.available
      ? "Reminders, \(values["dueTodayCount"]!) due today, \(values["overdueCount"]!) overdue, \(values["upcomingCount"]!) upcoming, \(values["undatedCount"]!) undated"
      : "Reminders, \(values["value"]!)"
    if values["hasNext"] == "true" {
      label += ", \(values["title"]!), \(values["list"]!), \(values["due"]!)"
    }
    if let error = values["error"], !error.isEmpty { label += ", \(error)" }
    return WidgetPresentation(
      text: values["value"]!,
      symbol: settings.showSymbol == false
        ? nil : item.symbol ?? settings.symbols?.resolve(status) ?? status.defaultSymbol,
      tint: settings.tints?[status.rawValue],
      hidden: settings.hideWhenEmpty == true && status == .empty,
      accessibilityLabel: label
    )
  }

  func nextTransition() -> Date? {
    guard access == .empty else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    return reminders.compactMap { record -> Date? in
      guard !record.completed, let due = record.due,
        due.hour != nil || due.minute != nil || due.second != nil,
        let date = Self.date(due, allDay: false, timeZone: timeZone), date >= now
      else { return nil }
      // A deadline equal to now is still due. Wake just after it becomes overdue.
      return date.addingTimeInterval(0.001)
    }.reduce(midnight, min)
  }

}

enum RemindersStatus: String, Codable, CaseIterable, Sendable {
  case loading, overdue, dueToday, upcoming, undated, empty, unauthorized, unavailable

  var available: Bool { [.overdue, .dueToday, .upcoming, .undated, .empty].contains(self) }
  var rank: Int { Self.allCases.firstIndex(of: self)! }
  var defaultSymbol: ItemSymbol {
    switch self {
    case .overdue: "exclamationmark.circle"
    case .unauthorized, .unavailable: "exclamationmark.triangle"
    default: "checklist"
    }
  }
}

struct ReminderRecord: Codable, Equatable, Sendable {
  var id: String
  var listId: String
  var title: String
  var due: DateComponents?
  var completed = false

  var displayTitle: String {
    let cleaned = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return cleaned.isEmpty ? "Untitled reminder" : cleaned
  }
}

struct SelectedReminder: Equatable, Sendable {
  var record: ReminderRecord
  var status: RemindersStatus
  var date: Date?
  var allDay = false
}

struct ReminderSelection {
  var status: RemindersStatus
  var entries: [SelectedReminder] = []
  var error = ""

  var label: String {
    switch status {
    case .loading: "Loading reminders"
    case .unauthorized: "Reminders permission denied"
    case .unavailable: error.isEmpty ? "Reminders unavailable" : error
    case .empty: "No reminders due"
    case .overdue, .dueToday: "\(count(.dueToday)) due · \(count(.overdue)) overdue"
    case .upcoming: "\(count(.upcoming)) upcoming"
    case .undated: "\(count(.undated)) undated"
    }
  }

  func count(_ status: RemindersStatus) -> Int { entries.filter { $0.status == status }.count }
}
