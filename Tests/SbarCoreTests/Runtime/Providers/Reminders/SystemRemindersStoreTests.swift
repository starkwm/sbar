import EventKit
import Foundation
import Testing

@testable import SbarCore

@Suite("SystemRemindersStore")
@MainActor
struct SystemRemindersStoreTests {
  @Test("fetchCompletion: background callbacks map records before resuming on the main actor")
  func backgroundCompletion() async throws {
    let records = try await ReminderFetch<[ReminderRecord]>().run { completion in
      let callback = SystemRemindersStore.fetchCompletion(completion)
      DispatchQueue.global().async {
        #expect(!Thread.isMainThread)
        // Create unsaved fixtures only. No authorization, fetch or save calls.
        let store = EKEventStore()
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = "Background task"
        reminder.dueDateComponents = DateComponents(year: 2026, month: 11, day: 2)
        reminder.isCompleted = true
        callback([reminder])
      }
      return {}
    }

    #expect(records.count == 1)
    #expect(records.first?.title == "Background task")
    #expect(records.first?.due?.day == 2)
    #expect(records.first?.completed == true)
    MainActor.assertIsolated()
  }

  @Test("fetchCompletion: a nil background result remains a read failure")
  func backgroundFailure() async {
    do {
      _ = try await ReminderFetch<[ReminderRecord]>().run { completion in
        let callback = SystemRemindersStore.fetchCompletion(completion)
        DispatchQueue.global().async { callback(nil) }
        return {}
      }
      Issue.record("Expected a read failure")
    } catch {
      #expect(error as? RemindersReadError == .unavailable)
    }
  }
}
