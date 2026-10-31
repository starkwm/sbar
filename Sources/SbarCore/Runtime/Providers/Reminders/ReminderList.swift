import Foundation

public struct ReminderList: Codable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var sourceId: String
  public var sourceTitle: String
}
