import Foundation
import Testing

@testable import SbarCore

struct ClockFormatterTests {
  @MainActor @Test("Explicit clock formats stay 24-hour")
  func explicitFormat() {
    let date = Date(timeIntervalSince1970: 13 * 3600 + 5 * 60 + 9)
    #expect(
      ClockFormatter.string(date, format: "HH:mm:ss", timeZone: TimeZone(secondsFromGMT: 0)!)
        == "13:05:09"
    )
  }
}
