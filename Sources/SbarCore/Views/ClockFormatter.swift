import Foundation

@MainActor
struct ClockFormatter {
  private static let formatters: [String: DateFormatter] = ["HH:mm", "HH:mm:ss"].reduce(into: [:]) {
    result,
    format in
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = format

    result[format] = formatter
  }

  static func string(_ date: Date, format: String?, timeZone: TimeZone = .autoupdatingCurrent)
    -> String
  {
    guard let format, let formatter = formatters[format] else {
      return date.formatted(date: .omitted, time: .shortened)
    }

    formatter.timeZone = timeZone

    return formatter.string(from: date)
  }
}
