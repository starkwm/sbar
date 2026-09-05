import ArgumentParser
import Foundation
import Testing

@testable import Sbar

struct ArgumentsTests {
  @Test func startup() throws {
    #expect(try Arguments.parseAsRoot([]) is StartCommand)
    let command = try #require(
      Arguments.parseAsRoot(["--config", "/tmp/custom.json"]) as? StartCommand
    )
    #expect(command.configurationURL.path == "/tmp/custom.json")
    #expect(try Arguments.parseAsRoot(["start"]) is StartCommand)
    for arguments in [
      ["--config"], ["--config="], ["unknown"], ["query", "extra"], ["trigger"], ["set", "clock"],
    ] {
      #expect(throws: (any Error).self) { try Arguments.parseAsRoot(arguments) }
    }
  }

  @Test func clients() throws {
    #expect(try Arguments.parseAsRoot(["stop"]) is StopCommand)
    #expect(try Arguments.parseAsRoot(["validate"]) is ValidateCommand)
    let validation = try #require(
      Arguments.parseAsRoot(["validate", "--config", "/tmp/check.json"]) as? ValidateCommand
    )
    #expect(validation.config == "/tmp/check.json")
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(["query", "--diagnostics", "--displays"])
    }
    #expect(throws: (any Error).self) { try Arguments.parseAsRoot(["validate", "--config="]) }
    let diagnostics = try #require(
      Arguments.parseAsRoot(["query", "--diagnostics"]) as? QueryCommand
    )
    #expect(diagnostics.diagnostics)
    let displays = try #require(Arguments.parseAsRoot(["query", "--displays"]) as? QueryCommand)
    #expect(displays.displays)
    #expect(try Arguments.parseAsRoot(["query"]) is QueryCommand)
    #expect(try Arguments.parseAsRoot(["reload"]) is ReloadCommand)
    #expect(try Arguments.parseAsRoot(["subscribe"]) is SubscribeCommand)
    let query = try #require(
      Arguments.parseAsRoot(["query", "--socket", "/tmp/test.sock"]) as? QueryCommand
    )
    #expect(query.options.socket == "/tmp/test.sock")
    let trigger = try #require(
      Arguments.parseAsRoot(["trigger", "refresh", "{} "]) as? TriggerCommand
    )
    #expect(trigger.event == "refresh")
    let set = try #require(
      Arguments.parseAsRoot(["set", "clock", "enabled", "false"]) as? SetCommand
    )
    #expect(set.itemID == "clock")
    #expect(set.value == "false")
  }
}
