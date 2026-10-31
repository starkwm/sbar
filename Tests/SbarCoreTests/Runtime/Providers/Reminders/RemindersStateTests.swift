import Foundation
import Testing

@testable import SbarCore

@Suite("RemindersState")
struct RemindersStateTests {
  private let now = ISO8601DateFormatter().date(from: "2026-10-31T12:00:00Z")!
  private let utc = TimeZone(secondsFromGMT: 0)!
  private let lists = [
    ReminderList(id: "home", title: "Tasks", sourceId: "a", sourceTitle: "Local"),
    ReminderList(id: "work", title: "Tasks", sourceId: "b", sourceTitle: "Work"),
  ]

  @Test(
    "selection: counts disjoint deadlines, excludes completed and deduplicates recurring records"
  )
  func counts() {
    let old = record("old", day: 29)
    var completed = record("done", day: 29)
    completed.completed = true
    let state = state([
      record("future", day: 7, month: 11), record("beyond", day: 8, month: 11),
      record("today"), record("timed", hour: 13), record("passed", hour: 11),
      record("exact", hour: 12), old, old, completed,
      ReminderRecord(id: "undated", listId: "home", title: "Undated", due: nil),
    ])
    let values = state.textValues(settings: nil)

    #expect(values["overdueCount"] == "2")
    #expect(values["dueTodayCount"] == "3")
    #expect(values["upcomingCount"] == "1")
    #expect(values["undatedCount"] == "0")
    #expect(values["total"] == "6")
    #expect(values["title"] == "old")
    #expect(values["value"] == "3 due · 2 overdue")
    #expect(state.textValues(settings: .init(includeUndated: true))["total"] == "7")
  }

  @Test("selection: IDs distinguish duplicate names and missing IDs fail without partial counts")
  func listsAndErrors() {
    var work = record("work")
    work.listId = "work"
    var state = state([record("home"), work])

    #expect(state.textValues(settings: .init(listIds: ["work"]))["title"] == "work")
    state.lists[1].title = "Renamed"
    #expect(state.textValues(settings: .init(listIds: ["work"]))["list"] == "Renamed")
    let missing = state.textValues(settings: .init(listIds: ["home", "missing"]))
    #expect(missing["status"] == "unavailable")
    #expect(missing["total"] == "")
    #expect(missing["title"] == "")
    #expect(missing["error"]?.contains("missing") == true)

    var invalid = record("invalid")
    invalid.due = DateComponents(year: 2026, month: 2, day: 30)
    #expect(self.state([invalid]).selection(settings: nil).status == .unavailable)
  }

  @Test("selection: deadline boundaries, midnight, DST and floating timezones use civil days")
  func boundaries() {
    var state = state([record("dateOnly"), record("timed", hour: 12)])
    #expect(state.selection(settings: nil).count(.overdue) == 0)
    state.now = now.addingTimeInterval(0.01)
    #expect(state.selection(settings: nil).count(.overdue) == 1)
    state.now = ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z")!
    #expect(state.selection(settings: nil).count(.overdue) == 2)

    // New York falls back on November 1: seven calendar days are not 168 hours.
    state.now = ISO8601DateFormatter().date(from: "2026-10-31T16:00:00Z")!
    state.timeZone = TimeZone(identifier: "America/New_York")!
    state.reminders = [record("edge", day: 7, hour: 23, month: 11)]
    #expect(state.selection(settings: nil).count(.upcoming) == 1)

    state.reminders = [record("floating", hour: 13), record("dateOnly")]
    #expect(state.selection(settings: nil).count(.dueToday) == 2)
    state.timeZone = utc
    #expect(state.selection(settings: nil).count(.overdue) == 1)
    #expect(state.selection(settings: nil).count(.dueToday) == 1)
    state.reminders[0].due?.timeZone = TimeZone(identifier: "America/New_York")
    #expect(state.selection(settings: nil).count(.overdue) == 0)
  }

  @Test("selection: sorting is deterministic and undated tasks are the final fallback")
  func sorting() {
    let undated = ReminderRecord(id: "none", listId: "home", title: "  ", due: nil)
    var state = state([record("z"), record("a"), record("timed", hour: 13), undated])

    #expect(state.selection(settings: nil).entries.map(\.record.id) == ["timed", "a", "z"])
    state.reminders = [undated]
    #expect(state.selection(settings: nil).status == .empty)
    let values = state.textValues(settings: .init(includeUndated: true))
    #expect(values["status"] == "undated")
    #expect(values["title"] == "Untitled reminder")
    #expect(values["due"] == "No due date")
    #expect(values["dueTime"] == "")
    #expect(values["hasDueDate"] == "false")
  }

  @Test("textValues: unavailable data is not reported as zero or retained task details")
  func states() {
    for status in [RemindersStatus.loading, .unauthorized, .unavailable] {
      var state = state([record("private")])
      state.access = status
      let values = state.textValues(settings: nil)

      #expect(values["available"] == "false")
      #expect(values["total"] == "")
      #expect(values["title"] == "")
      #expect(values["hasNext"] == "false")
    }
    let values = state([]).textValues(settings: nil)
    #expect(values["total"] == "0")
    #expect(values["available"] == "true")
  }

  @Test("presentation: overrides, empty hiding and accessibility preserve meaning")
  func presentation() {
    var item = Item(
      id: "tasks",
      type: .reminders,
      reminders: .init(
        symbols: .init(overdue: .system("star")),
        tints: ["overdue": "#FF0000"],
        hideWhenEmpty: true
      )
    )
    let state = state([record("old", day: 29)])
    let result = state.presentation(for: item)

    #expect(result.symbol == "star")
    #expect(result.tint == "#FF0000")
    #expect(result.accessibilityLabel.contains("1 overdue"))
    #expect(result.accessibilityLabel.contains("old, Tasks"))
    #expect(!result.hidden)
    #expect(self.state([]).presentation(for: item).hidden)
    #expect(!RemindersState(access: .unauthorized).presentation(for: item).hidden)
    item.symbol = "heart"
    #expect(state.presentation(for: item).symbol == "heart")
    item.reminders?.showSymbol = false
    #expect(state.presentation(for: item).symbol == nil)
  }

  @Test("nextTransition: waits until just after a timed deadline or the next midnight")
  func transitions() {
    let state = state([record("now", hour: 12)])
    #expect(state.nextTransition()! > now)
    #expect(state.nextTransition()! < now.addingTimeInterval(1))
    #expect(self.state([record("day")]).nextTransition() == now.addingTimeInterval(12 * 3600))
  }

  private func record(_ id: String, day: Int = 31, hour: Int? = nil, month: Int = 10)
    -> ReminderRecord
  {
    ReminderRecord(
      id: id,
      listId: "home",
      title: id,
      due: DateComponents(year: 2026, month: month, day: day, hour: hour)
    )
  }

  private func state(_ records: [ReminderRecord]) -> RemindersState {
    RemindersState(access: .empty, lists: lists, reminders: records, now: now, timeZone: utc)
  }
}
