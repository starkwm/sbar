import EventKit
import Foundation

@MainActor
final class SystemRemindersStore {
  // EventKit invokes this callback on its own queue. Only immutable records cross
  // into ReminderFetch, which resumes its continuation on the main actor.
  nonisolated static func fetchCompletion(
    _ completion: @escaping @Sendable ([ReminderRecord]?) -> Void
  ) -> @Sendable ([EKReminder]?) -> Void {
    { reminders in
      completion(
        reminders?.map {
          ReminderRecord(
            id: $0.calendarItemIdentifier,
            listId: $0.calendar.calendarIdentifier,
            title: $0.title ?? "",
            due: $0.dueDateComponents,
            completed: $0.isCompleted
          )
        }
      )
    }
  }

  private lazy var store = EKEventStore()
  private lazy var authorization: RemindersAuthorization = {
    let store = store
    return RemindersAuthorization(
      status: { EKEventStore.authorizationStatus(for: .reminder) },
      request: { try await store.requestFullAccessToReminders() }
    )
  }()

  func lists() async throws -> [ReminderList] {
    try await authorization.authorize()
    try Task.checkCancellation()
    return metadata(store.calendars(for: .reminder))
  }

  func read(listIds: Set<String>?, now: Date) async -> RemindersState {
    do {
      try await authorization.authorize()
      try Task.checkCancellation()
      let calendars = store.calendars(for: .reminder)
      let lists = metadata(calendars)
      let selected = calendars.filter { listIds == nil || listIds!.contains($0.calendarIdentifier) }
      // An empty array must never accidentally become a query for all lists.
      guard !selected.isEmpty else { return RemindersState(access: .empty, lists: lists, now: now) }
      let predicate = store.predicateForIncompleteReminders(
        withDueDateStarting: nil,
        ending: nil,
        calendars: selected
      )
      let fetch = ReminderFetch<[ReminderRecord]>()
      let records = try await fetch.run { completion in
        let token = self.store.fetchReminders(
          matching: predicate,
          completion: Self.fetchCompletion(completion)
        )
        return { self.store.cancelFetchRequest(token) }
      }
      try Task.checkCancellation()
      switch EKEventStore.authorizationStatus(for: .reminder) {
      case .fullAccess, .authorized: break
      case .denied, .restricted: throw RemindersReadError.unauthorized
      default: throw RemindersReadError.unavailable
      }
      return RemindersState(access: .empty, lists: lists, reminders: records, now: now)
    } catch RemindersReadError.unauthorized {
      return RemindersState(access: .unauthorized, now: now)
    } catch {
      return RemindersState(access: .unavailable, now: now, error: "Reminders unavailable")
    }
  }

  private func metadata(_ calendars: [EKCalendar]) -> [ReminderList] {
    calendars.map {
      ReminderList(
        id: $0.calendarIdentifier,
        title: $0.title,
        sourceId: $0.source.sourceIdentifier,
        sourceTitle: $0.source.title
      )
    }.sorted {
      ($0.sourceTitle, $0.title, $0.id) < ($1.sourceTitle, $1.title, $1.id)
    }
  }
}

enum RemindersReadError: Error, LocalizedError {
  case unauthorized, unavailable

  var errorDescription: String? {
    switch self {
    case .unauthorized:
      "Reminders permission denied for Sbar EventKit. Allow access in System Settings > Privacy & Security > Reminders."
    case .unavailable: "Reminders unavailable."
    }
  }
}
