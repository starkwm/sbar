import Foundation
import Testing

@testable import SbarCore

@MainActor
@Suite("DateTimeFormatter")
struct DateTimeFormatterTests {
  private let date = Date(timeIntervalSince1970: 13 * 3600 + 5 * 60 + 9)
  private let locale = Locale(identifier: "en_US_POSIX")
  private let timeZone = TimeZone(secondsFromGMT: 0)!

  @Test(
    "string: supports custom patterns",
    arguments: [
      ("yyyy-MM-dd", "1970-01-01"),
      ("HH:mm:ss", "13:05:09"),
      ("h:mm a", "1:05 PM"),
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
      (DateTimeStyle.short, DateFormatter.Style.short), (.medium, .medium),
      (.long, .long), (.full, .full), (.none, .none),
    ]
  )
  func presets(format: DateTimeStyle, style: DateFormatter.Style) {
    _ = string("yyyy")
    let expected = DateFormatter()
    expected.locale = locale
    expected.timeZone = timeZone
    expected.dateStyle = style

    #expect(
      DateTimeFormatter.string(
        date,
        dateStyle: format,
        timeStyle: DateTimeStyle.none,
        locale: locale,
        timeZone: timeZone
      ) == expected.string(from: date)
    )
    #expect(string("yyyy-MM-dd") == "1970-01-01")
  }

  @Test("string: preserves the default for omitted and empty formats")
  func defaultFormat() {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.timeStyle = .short
    _ = string("yyyy")
    let expected = formatter.string(from: date)

    #expect(string(nil) == expected)
    #expect(string("") == expected)
  }

  @Test("string: respects locale and time zone changes")
  func regionalSettings() {
    #expect(
      DateTimeFormatter.string(
        date,
        format: "MMMM",
        locale: Locale(identifier: "fr_FR"),
        timeZone: timeZone
      ) == "janvier"
    )
    #expect(string("MMMM") == "January")
    #expect(
      DateTimeFormatter.string(
        date,
        format: "yyyy-MM-dd",
        locale: locale,
        timeZone: TimeZone(secondsFromGMT: 12 * 3600)!
      ) == "1970-01-02"
    )
    #expect(string("yyyy-MM-dd") == "1970-01-01")
  }

  @Test("string: combines styles and gives custom formats precedence")
  func combinedStyles() {
    let expected = DateFormatter()
    expected.locale = locale
    expected.timeZone = timeZone
    expected.dateStyle = .long
    expected.timeStyle = .medium

    #expect(
      DateTimeFormatter.string(
        date,
        dateStyle: .long,
        timeStyle: .medium,
        locale: locale,
        timeZone: timeZone
      ) == expected.string(from: date)
    )
    #expect(
      DateTimeFormatter.string(
        date,
        format: "yyyy",
        dateStyle: .full,
        timeStyle: .full,
        locale: locale,
        timeZone: timeZone
      ) == "1970"
    )
    #expect(
      DateTimeFormatter.string(
        date,
        format: "",
        dateStyle: .long,
        timeStyle: .medium,
        locale: locale,
        timeZone: timeZone
      ) == expected.string(from: date)
    )
  }

  private func string(_ format: String?) -> String {
    DateTimeFormatter.string(date, format: format, locale: locale, timeZone: timeZone)
  }
}
