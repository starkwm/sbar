import Foundation
import Testing

@testable import SbarCore

@MainActor
@Suite("DateItemFormatter")
struct DateItemFormatterTests {
  private let date = Date(timeIntervalSince1970: 13 * 3600 + 5 * 60 + 9)
  private let locale = Locale(identifier: "en_US_POSIX")
  private let timeZone = TimeZone(secondsFromGMT: 0)!

  @Test(
    "string: supports custom patterns",
    arguments: [
      ("yyyy-MM-dd", "1970-01-01"),
      ("dd/MM/yyyy", "01/01/1970"),
      ("EEEE, d MMMM", "Thursday, 1 January"),
      ("MMM d 'at' HH:mm", "Jan 1 at 13:05"),
    ]
  )
  func customPatterns(pattern: String, expected: String) {
    #expect(string(pattern) == expected)
  }

  @Test(
    "string: supports localized presets after custom patterns",
    arguments: [
      ("short", DateFormatter.Style.short), ("medium", .medium),
      ("long", .long), ("full", .full),
    ]
  )
  func presets(format: String, style: DateFormatter.Style) {
    _ = string("yyyy")
    let expected = DateFormatter()
    expected.locale = locale
    expected.timeZone = timeZone
    expected.dateStyle = style
    #expect(string(format) == expected.string(from: date))
    #expect(string("yyyy-MM-dd") == "1970-01-01")
  }

  @Test("string: preserves the default for omitted and empty formats")
  func defaultFormat() {
    let expected = date.formatted(
      Date.FormatStyle(locale: locale, timeZone: timeZone).weekday().month().day()
    )
    #expect(string(nil) == expected)
    #expect(string("") == expected)
  }

  @Test("string: respects locale and time zone changes")
  func regionalSettings() {
    #expect(
      DateItemFormatter.string(
        date,
        format: "MMMM",
        locale: Locale(identifier: "fr_FR"),
        timeZone: timeZone
      ) == "janvier"
    )
    #expect(string("MMMM") == "January")
    #expect(
      DateItemFormatter.string(
        date,
        format: "yyyy-MM-dd",
        locale: locale,
        timeZone: TimeZone(secondsFromGMT: 12 * 3600)!
      ) == "1970-01-02"
    )
    #expect(string("yyyy-MM-dd") == "1970-01-01")
  }

  private func string(_ format: String?) -> String {
    DateItemFormatter.string(date, format: format, locale: locale, timeZone: timeZone)
  }
}
