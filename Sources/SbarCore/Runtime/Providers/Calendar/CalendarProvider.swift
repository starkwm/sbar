import EventKit
import Foundation

@MainActor
final class CalendarProvider: NSObject {
  private(set) var lookaheadDays = 7

  private let read: @Sendable (Int, Date) async -> CalendarState
  private var task: Task<Void, Never>?
  private var update: (@MainActor (CalendarState) -> Void)?
  private var generation = 0
  private var refreshGeneration = 0

  init(read: (@Sendable (Int, Date) async -> CalendarState)? = nil) {
    let store = SystemCalendarStore()
    self.read = read ?? { days, now in await store.read(lookaheadDays: days, now: now) }
    super.init()
  }

  func start(lookaheadDays: Int, update: @escaping @MainActor (CalendarState) -> Void) {
    stop()
    self.lookaheadDays = lookaheadDays
    self.update = update
    generation += 1
    let generation = generation

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(calendarDidChange),
      name: .EKEventStoreChanged,
      object: nil
    )
    task = Task { [weak self] in
      while !Task.isCancelled {
        await self?.reload()
        guard !Task.isCancelled, self?.generation == generation else { return }

        do { try await Task.sleep(for: .seconds(60)) } catch { return }
      }
    }
  }

  func stop() {
    generation += 1
    refreshGeneration += 1
    task?.cancel()
    task = nil
    update = nil
    NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: nil)
  }

  func reload() async {
    refreshGeneration += 1
    let refreshGeneration = refreshGeneration
    let generation = generation
    var state = await read(lookaheadDays, Date())
    guard !Task.isCancelled, generation == self.generation,
      refreshGeneration == self.refreshGeneration
    else { return }

    state.now = Date()
    update?(state)
  }

  @objc private func calendarDidChange(_ notification: Notification) {
    Task { [weak self] in await self?.reload() }
  }
}

actor SystemCalendarStore {
  private let store = EKEventStore()

  func read(lookaheadDays: Int, now: Date) async -> CalendarState {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .notDetermined, .writeOnly:
      do {
        guard try await store.requestFullAccessToEvents() else {
          return CalendarState(access: .unauthorized, now: now)
        }
      } catch {
        return CalendarState(access: .unavailable, now: now)
      }
    case .denied, .restricted:
      return CalendarState(access: .unauthorized, now: now)
    case .fullAccess, .authorized:
      break
    @unknown default:
      return CalendarState(access: .unavailable, now: now)
    }

    let end = now.addingTimeInterval(Double(lookaheadDays) * 86400)
    let predicate = store.predicateForEvents(
      withStart: now.addingTimeInterval(-86400),
      end: end,
      calendars: nil
    )
    let events = store.events(matching: predicate).compactMap { event -> CalendarEvent? in
      guard let start = event.startDate, let finish = event.endDate, finish > now, start < end
      else { return nil }

      return CalendarEvent(
        title: event.title ?? "",
        calendar: event.calendar?.title ?? "",
        start: start,
        end: finish,
        allDay: event.isAllDay
      )
    }

    return CalendarState(access: .empty, events: events, now: now)
  }
}
