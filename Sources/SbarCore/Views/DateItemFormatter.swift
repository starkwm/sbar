import Foundation

@MainActor
struct DateItemFormatter {
  private static let formatter = DateFormatter()

  static func string(
    _ date: Date,
    format: String?,
    locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String {
    guard let format, !format.isEmpty else {
      return date.formatted(
        Date.FormatStyle(locale: locale, timeZone: timeZone).weekday().month().day()
      )
    }

    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateStyle = .none
    formatter.timeStyle = .none

    switch format {
    case "short": formatter.dateStyle = .short
    case "medium": formatter.dateStyle = .medium
    case "long": formatter.dateStyle = .long
    case "full": formatter.dateStyle = .full
    default: formatter.dateFormat = format
    }

    return formatter.string(from: date)
  }
}
