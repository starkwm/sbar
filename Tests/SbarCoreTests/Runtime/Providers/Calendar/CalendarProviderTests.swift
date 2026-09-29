import EventKit
import Foundation
import Synchronization
import Testing

@testable import SbarCore

@Suite("CalendarState")
struct CalendarStateTests {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  @Test("selectedEvent(settings:): ongoing timed events take priority, then all-day events")
  func selection() {
    let allDay = CalendarEvent(
      title: "Holiday",
      calendar: "Home",
      start: now.addingTimeInterval(-3600),
      end: now.addingTimeInterval(3600),
      allDay: true
    )
    let timed = CalendarEvent(
      title: "Standup",
      calendar: "Work",
      start: now.addingTimeInterval(-600),
      end: now.addingTimeInterval(600),
      allDay: false
    )
    let later = CalendarEvent(
      title: "Review",
      calendar: "Work",
      start: now.addingTimeInterval(7200),
      end: now.addingTimeInterval(9000),
      allDay: false
    )
    var state = CalendarState(access: .empty, events: [later, allDay, timed], now: now)

    #expect(state.selectedEvent(settings: nil) == timed)
    #expect(state.status(settings: nil) == .ongoing)
    #expect(state.textValues(settings: nil)["value"] == "Now Standup")
    #expect(state.textValues(settings: nil)["minutesUntil"] == "0")

    state.now = now.addingTimeInterval(900)

    #expect(state.selectedEvent(settings: nil) == allDay)
    #expect(state.textValues(settings: nil)["value"] == "All day Holiday")

    let noAllDay = CalendarConfiguration(includeAllDay: false)

    #expect(state.selectedEvent(settings: noAllDay) == later)
    #expect(state.textValues(settings: noAllDay)["minutesUntil"] == "105")

    state.now = now.addingTimeInterval(10_000)

    #expect(state.status(settings: noAllDay) == .empty)
  }

  @Test("textValues(settings:): access failures and empty results have distinct states")
  func states() {
    for (status, label) in [
      (CalendarStatus.loading, "Loading calendar"),
      (.empty, "No events"),
      (.unauthorized, "Calendar permission denied"),
      (.unavailable, "Calendar unavailable"),
    ] {
      let state = CalendarState(access: status, now: now)
      let values = state.textValues(settings: nil)

      #expect(values["status"] == status.rawValue)
      #expect(values["value"] == label)
      #expect(values["title"] == "")
      #expect(values["available"] == String(status == .empty))
    }
  }

  @Test("presentation(for:): status symbols, tints, visibility and overrides apply")
  func appearance() throws {
    var item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"calendar","type":"calendar","calendar":{"symbols":{"font":"Test","size":18,"ongoing":{"glyph":"C"}},"tints":{"ongoing":"#00FF00"},"hideWhenEmpty":true}}"##
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()

    let event = CalendarEvent(
      title: "Meeting",
      calendar: "Work",
      start: now.addingTimeInterval(-60),
      end: now.addingTimeInterval(600),
      allDay: false
    )
    let state = CalendarState(access: .empty, events: [event], now: now)
    let presentation = state.presentation(for: item)

    #expect(presentation.symbol == .glyph("C", font: "Test", size: 18))
    #expect(presentation.tint == "#00FF00")
    #expect(presentation.accessibilityLabel == "Calendar, Now Meeting")
    #expect(!presentation.hidden)

    item.symbol = "star"
    #expect(state.presentation(for: item).symbol == "star")

    item.calendar?.showSymbol = false
    #expect(state.presentation(for: item).symbol == nil)

    let empty = CalendarState(access: .empty, now: now)
    #expect(empty.presentation(for: item).hidden)
    #expect(!CalendarState(access: .unauthorized, now: now).presentation(for: item).hidden)
  }

  @Test("CalendarConfiguration.validate: round trips and rejects invalid settings")
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"calendar","type":"calendar","calendar":{"lookaheadDays":3,"includeAllDay":false,"timeFormat":"HH:mm","symbols":{"upcoming":"calendar"},"tints":{"empty":"#112233"}}}"##
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()

    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    #expect(item.calendar?.resolvedLookaheadDays == 3)

    for settings in [
      ##"{"lookaheadDays":0}"##,
      ##"{"lookaheadDays":31}"##,
      ##"{"timeFormat":" "}"##,
      ##"{"tints":{"wrong":"#112233"}}"##,
      ##"{"tints":{"empty":"red"}}"##,
      ##"{"symbols":{"wrong":"star"}}"##,
      ##"{"symbols":{"upcoming":{"glyph":"C"}}}"##,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(
          CalendarConfiguration.self,
          from: Data(settings.utf8)
        )
        try settings.validate(path: "calendar")
      }
    }

    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "text", type: .text, calendar: .init())])
      ).validate()
    }
  }

  @Test("ProviderRuntime: templates and manual snapshots use the selected event")
  @MainActor
  func runtime() {
    let manual = Item(
      id: "calendar",
      type: .calendar,
      text: "{{#status=upcoming}}{{title}} in {{minutesUntil}}m{{/status}}",
      refresh: .init(mode: .manual)
    )
    let event = CalendarEvent(
      title: "Review",
      calendar: "Work",
      start: now.addingTimeInterval(300),
      end: now.addingTimeInterval(1800),
      allDay: false
    )
    let first = CalendarState(access: .empty, events: [event], now: now)
    let later = CalendarState(access: .empty, events: [event], now: now.addingTimeInterval(120))
    let runtime = ProviderRuntime(calendar: CalendarProvider { _, _ in first })
    defer { runtime.stop() }

    runtime.configure(Configuration(bar: .init(), items: .init(right: [manual])))
    runtime.updateWidgetState(.calendar(first), for: .calendar)
    runtime.trigger(manual.id)

    #expect(runtime.presentation(for: manual)?.text == "Review in 5m")

    runtime.updateWidgetState(.calendar(later), for: .calendar)
    #expect(runtime.presentation(for: manual)?.text == "Review in 5m")

    runtime.trigger(manual.id)
    #expect(runtime.presentation(for: manual)?.text == "Review in 3m")
  }
}

@Suite("CalendarProvider")
@MainActor
struct CalendarProviderTests {
  @Test("start: reads on activation and Calendar changes, then stops")
  func lifecycle() async throws {
    let reads = Mutex(0)
    let provider = CalendarProvider { _, now in
      reads.withLock { $0 += 1 }
      return CalendarState(access: .empty, now: now)
    }
    defer { provider.stop() }
    var updates = 0

    provider.start(lookaheadDays: 3) { _ in updates += 1 }
    try await waitUntil { updates == 1 }

    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    try await waitUntil { updates == 2 }

    provider.stop()
    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    try await Task.sleep(for: .milliseconds(30))

    #expect(reads.withLock { $0 } == 2)
    #expect(updates == 2)
    #expect(provider.lookaheadDays == 3)
  }

  @Test("start: queued Calendar changes from a previous activation do not start a read")
  func queuedChangeAfterRestart() async throws {
    let reads = Mutex<[Int]>([])
    let provider = CalendarProvider { days, now in
      reads.withLock { $0.append(days) }
      return CalendarState(access: .empty, now: now)
    }
    defer { provider.stop() }
    var updates = 0

    provider.start(lookaheadDays: 1) { _ in updates += 1 }
    try await waitUntil { updates == 1 }

    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    provider.start(lookaheadDays: 30) { _ in updates += 1 }
    try await waitUntil { updates == 2 }
    try await Task.sleep(for: .milliseconds(30))

    #expect(reads.withLock { $0 } == [1, 30])
    #expect(updates == 2)
  }

  @Test("stop: queued Calendar changes do not start a read after stopping")
  func queuedChangeAfterStop() async throws {
    let reads = Mutex(0)
    let provider = CalendarProvider { _, now in
      reads.withLock { $0 += 1 }
      return CalendarState(access: .empty, now: now)
    }
    defer { provider.stop() }
    var updates = 0

    provider.start(lookaheadDays: 7) { _ in updates += 1 }
    try await waitUntil { updates == 1 }

    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    provider.stop()
    try await Task.sleep(for: .milliseconds(30))

    #expect(reads.withLock { $0 } == 1)
    #expect(updates == 1)
  }
}

@Suite("SystemCalendarStore")
struct SystemCalendarStoreTests {
  @Test(
    "event(_:status:now:end:): canceled events are excluded and other statuses are retained",
    arguments: [EKEventStatus.canceled, .none, .confirmed, .tentative]
  )
  func eventStatus(_ status: EKEventStatus) {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let store = EKEventStore()
    let calendar = EKCalendar(for: .event, eventStore: store)
    calendar.title = "Work"
    let event = EKEvent(eventStore: store)
    event.title = "Meeting"
    event.calendar = calendar
    event.startDate = now.addingTimeInterval(300)
    event.endDate = now.addingTimeInterval(1800)

    let result = SystemCalendarStore.event(
      event,
      status: status,
      now: now,
      end: now.addingTimeInterval(86400)
    )

    if status == .canceled {
      #expect(result == nil)
    } else {
      #expect(
        result
          == CalendarEvent(
            title: "Meeting",
            calendar: "Work",
            start: event.startDate,
            end: event.endDate,
            allDay: false
          )
      )
    }
  }
}
