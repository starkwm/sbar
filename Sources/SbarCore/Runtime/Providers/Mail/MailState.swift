struct MailState: Equatable, Sendable {
  enum Status: String, Sendable {
    case available, closed, unauthorized, unavailable
  }

  var status: Status = .unavailable
  var unreadCount: Int?

  var hasUnread: Bool { status == .available && (unreadCount ?? 0) > 0 }

  var text: String {
    switch status {
    case .available: unreadCount.map { "\($0) unread" } ?? "Mail unavailable"
    case .closed: "Mail closed"
    case .unauthorized: "Mail permission denied"
    case .unavailable: "Mail unavailable"
    }
  }

  func presentation(for item: Item) -> WidgetPresentation {
    WidgetPresentation(
      text: text,
      symbol: item.symbol ?? (hasUnread ? "envelope.badge" : "envelope"),
      accessibilityLabel: status == .available ? "Inbox, \(text)" : text
    )
  }
}
