import Foundation

@MainActor
struct DateTimeFormatter {
  private static let formatter = DateFormatter()

  static func string(
    _ date: Date,
    format: String? = nil,
    dateStyle: DateTimeStyle? = nil,
    timeStyle: DateTimeStyle? = nil,
    locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String {
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateStyle = style(dateStyle ?? .none)
    formatter.timeStyle = style(timeStyle ?? .short)

    if let format, !format.isEmpty {
      formatter.dateFormat = format
    }

    return formatter.string(from: date)
  }

  private static func style(_ style: DateTimeStyle) -> DateFormatter.Style {
    switch style {
    case .none: .none
    case .short: .short
    case .medium: .medium
    case .long: .long
    case .full: .full
    }
  }
}
