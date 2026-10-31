import Foundation
import Testing

@testable import SbarCore

@Suite("PomodoroConfiguration")
struct PomodoroConfigurationTests {
  @Test("resolve: shared settings inherit explicit values and reject active conflicts")
  func sharedSettings() throws {
    let owner = Item(id: "timer", type: .pomodoro, pomodoro: .init(focusMinutes: 10))
    var mirror = Item(id: "mirror", type: .pomodoro)
    var configuration = Configuration(bar: .init(), items: .init(right: [owner, mirror]))
    try configuration.validate()
    #expect(try PomodoroConfiguration.resolve(configuration.items.active).timing.focusMinutes == 10)
    #expect(try PomodoroConfiguration.resolve([]).timing == PomodoroTiming())

    mirror.pomodoro = .init(focusMinutes: 20)
    configuration.items.right[1] = mirror
    #expect(throws: ConfigurationError.self) { try configuration.validate() }
    configuration.items.right[1].enabled = false
    try configuration.validate()
  }

  @Test("validate: schema bounds and action operations match configuration validation")
  func validation() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let pomodoro = try #require(definitions["pomodoro"] as? [String: Any])
    let properties = try #require(pomodoro["properties"] as? [String: Any])
    for key in ["focusMinutes", "shortBreakMinutes", "longBreakMinutes", "cyclesBeforeLongBreak"] {
      let field = try #require(properties[key] as? [String: Any])
      let minimum = try #require(field["minimum"] as? Int)
      let maximum = try #require(field["maximum"] as? Int)
      for value in [minimum - 1, minimum, maximum, maximum + 1] {
        let data = try JSONSerialization.data(withJSONObject: [key: value])
        let decoded = try JSONDecoder().decode(PomodoroConfiguration.self, from: data)
        if (minimum...maximum).contains(value) {
          try decoded.validate(path: "pomodoro")
        } else {
          #expect(throws: ConfigurationError.self) { try decoded.validate(path: "pomodoro") }
        }
      }
    }
    for operation in PomodoroOperation.allCases {
      let action = ItemAction(kind: .pomodoro, value: operation.rawValue)
      if operation == .status {
        #expect(throws: ConfigurationError.self) { try action.validate(path: "action") }
      } else {
        try action.validate(path: "action")
      }
    }
    for settings in [
      ##"{"tints":{"bad":"#112233"}}"##, ##"{"symbols":{"bad":"timer"}}"##,
      ##"{"symbols":{"focus":{"glyph":"X"}}}"##, ##"{"focusMinutes":1.5}"##,
    ] {
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(PomodoroConfiguration.self, from: Data(settings.utf8)).validate(
          path: "pomodoro"
        )
      }
    }
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "bad", type: .text, pomodoro: .init())])
      ).validate()
    }
  }
}
