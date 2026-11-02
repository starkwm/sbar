import Foundation

struct EventKitRequest: Codable, Sendable {
  enum Operation: String, Codable, Sendable { case ping, begin, poll, cancel }
  enum Resource: String, Codable, Sendable { case lists, reminders, calendar }

  var operation: Operation
  var id: UUID = UUID()
  var resource: Resource?
  var listIds: Set<String>?
  var lookaheadDays: Int?
}

struct EventKitResponse: Codable, Sendable {
  var pending = false
  var lists: [ReminderList]?
  var reminders: RemindersState?
  var calendar: CalendarState?
  var error: String?
}

struct EventKitHelperError: LocalizedError {
  var message: String
  var errorDescription: String? { message }
}
