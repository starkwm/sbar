import Foundation
import Testing

@testable import SbarCore

@Suite("ClockFormatter")
struct ClockFormatterTests {
  @MainActor @Test("string(_:format:timeZone:): preserves explicit 24-hour formats")
  func stringPreservesExplicit24HourFormats() {
    let date = Date(timeIntervalSince1970: 13 * 3600 + 5 * 60 + 9)

    #expect(
      ClockFormatter.string(date, format: "HH:mm:ss", timeZone: TimeZone(secondsFromGMT: 0)!)
        == "13:05:09"
    )
  }
}
