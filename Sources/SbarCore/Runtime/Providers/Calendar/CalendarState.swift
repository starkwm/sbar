import Foundation

enum CalendarStatus: String, CaseIterable, Sendable {
  case loading, upcoming, ongoing, empty, unauthorized, unavailable

  var defaultSymbol: ItemSymbol {
    switch self {
    case .loading: "calendar"
    case .upcoming: "calendar"
    case .ongoing: "calendar.badge.clock"
    case .empty: "calendar"
    case .unauthorized: "calendar.badge.exclamationmark"
    case .unavailable: "calendar.badge.exclamationmark"
    }
  }
}

struct CalendarEvent: Equatable, Sendable {
  var title: String
  var calendar: String
  var start: Date
  var end: Date
  var allDay: Bool
}

struct CalendarState: Equatable, Sendable {
  var access: CalendarStatus = .loading
  var events: [CalendarEvent] = []
  var now = Date()

  var text: String { textValues(settings: nil)["value"] ?? "Calendar unavailable" }

  func selectedEvent(settings: CalendarConfiguration?) -> CalendarEvent? {
    guard access == .empty else { return nil }

    let horizon = now.addingTimeInterval(Double(settings?.resolvedLookaheadDays ?? 7) * 86400)

    return
      events
      .filter {
        $0.end > now && $0.start < horizon && (settings?.includeAllDay != false || !$0.allDay)
      }
      .min {
        let left = ($0.start <= now ? ($0.allDay ? 1 : 0) : 2, $0.start)
        let right = ($1.start <= now ? ($1.allDay ? 1 : 0) : 2, $1.start)

        return left < right
      }
  }

  func status(settings: CalendarConfiguration?) -> CalendarStatus {
    guard access == .empty else { return access }
    guard let event = selectedEvent(settings: settings) else { return .empty }

    return event.start <= now ? .ongoing : .upcoming
  }

  func textValues(settings: CalendarConfiguration?) -> [String: String] {
    let status = status(settings: settings)
    var values = [
      "status": status.rawValue,
      "available": String(status == .upcoming || status == .ongoing || status == .empty),
      "allDay": "false",
      "title": "",
      "calendar": "",
      "startTime": "",
      "endTime": "",
      "minutesUntil": "",
      "value": "",
    ]

    guard let event = selectedEvent(settings: settings) else {
      values["value"] =
        switch status {
        case .loading: "Loading calendar"
        case .empty: "No events"
        case .unauthorized: "Calendar permission denied"
        case .unavailable: "Calendar unavailable"
        case .upcoming, .ongoing: "No events"
        }

      return values
    }

    let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = title.isEmpty ? "Untitled event" : title
    let startTime = Self.time(event.start, format: settings?.timeFormat)
    let endTime = Self.time(event.end, format: settings?.timeFormat)
    let minutes = max(0, Int(ceil(event.start.timeIntervalSince(now) / 60)))
    let prefix = event.allDay ? "All day" : status == .ongoing ? "Now" : startTime

    values["allDay"] = String(event.allDay)
    values["title"] = name
    values["calendar"] = event.calendar
    values["startTime"] = startTime
    values["endTime"] = endTime
    values["minutesUntil"] = String(minutes)
    values["value"] = "\(prefix) \(name)"

    return values
  }

  func presentation(for item: Item) -> WidgetPresentation {
    let settings = item.calendar ?? CalendarConfiguration()
    let status = status(settings: settings)
    let text = textValues(settings: settings)["value"] ?? "Calendar unavailable"

    return WidgetPresentation(
      text: text,
      symbol: settings.showSymbol == false
        ? nil : item.symbol ?? settings.symbols?.resolve(status) ?? status.defaultSymbol,
      tint: settings.tints?[status.rawValue],
      hidden: settings.hideWhenEmpty == true && status == .empty,
      accessibilityLabel: "Calendar, \(text)"
    )
  }

  private static func time(_ date: Date, format: String?) -> String {
    guard let format else { return date.formatted(date: .omitted, time: .shortened) }

    let formatter = DateFormatter()
    formatter.dateFormat = format

    return formatter.string(from: date)
  }
}
