import Foundation

@MainActor
public enum RemindersDiscovery {
  public static func lists() async throws -> [ReminderList] {
    try await SystemRemindersStore().lists()
  }
}
