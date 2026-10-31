import Foundation
import Testing

@testable import SbarCore

@Suite("PomodoroState")
struct PomodoroStateTests {
  @Test("presentation: symbols, tints, templates and accessibility retain timer meaning")
  func presentation() throws {
    var item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"timer","type":"pomodoro","text":"{{phaseLabel}} {{remaining}} {{progress}}%{{#status=paused}} paused{{/status}}","pomodoro":{"symbols":{"font":"Test","size":18,"focus":{"glyph":"F"}},"tints":{"focus":"#112233","paused":"#445566"}}}"##
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    let state = PomodoroState(status: .paused, remaining: 750, completedSessions: 2)
    #expect(state.progress == 50)
    #expect(state.presentation(for: item).symbol == .glyph("F", font: "Test", size: 18))
    #expect(state.presentation(for: item).tint == "#445566")
    #expect(state.presentation(for: item).accessibilityLabel.contains("2 of 4"))
    item.symbol = "star"
    #expect(state.presentation(for: item).symbol == "star")
    item.pomodoro?.showSymbol = false
    #expect(state.presentation(for: item).symbol == nil)
    for text in ["{{#phase=wrong}}x{{/phase}}", "{{#status=wrong}}x{{/status}}", "{{unknown}}"] {
      item.text = text
      #expect(throws: (any Error).self) {
        try Configuration(bar: .init(), items: .init(right: [item])).validate()
      }
    }
  }
}
