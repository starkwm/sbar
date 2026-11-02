import Foundation

@MainActor
public enum RemindersDiscovery {
  public static func lists() async throws -> [ReminderList] {
    let response = try await EventKitClient.shared.request(.lists)
    guard let lists = response.lists else {
      throw EventKitHelperError(message: "EventKit helper returned no list metadata.")
    }
    return lists
  }
}
