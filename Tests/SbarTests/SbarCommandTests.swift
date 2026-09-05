import ArgumentParser
import Foundation
import Testing

@testable import Sbar

@Suite("SbarCommand")
struct SbarCommandTests {
  @Test("parseAsRoot(_:): parses startup options and rejects invalid arguments")
  func parseAsRootParsesStartupOptions() throws {
    #expect(try SbarCommand.parseAsRoot([]) is StartCommand)

    let command = try #require(
      SbarCommand.parseAsRoot(["--config", "/tmp/custom.json"]) as? StartCommand
    )
    #expect(command.configurationURL.path == "/tmp/custom.json")
    #expect(try SbarCommand.parseAsRoot(["start"]) is StartCommand)

    for arguments in [
      ["--config"], ["--config="], ["unknown"], ["query", "extra"], ["trigger"], ["set", "clock"],
    ] {
      #expect(throws: (any Error).self) { try SbarCommand.parseAsRoot(arguments) }
    }
  }

  @Test("parseAsRoot(_:): parses client commands and validates their options")
  func parseAsRootParsesClientCommands() throws {
    #expect(try SbarCommand.parseAsRoot(["stop"]) is StopCommand)
    #expect(try SbarCommand.parseAsRoot(["validate"]) is ValidateCommand)

    let validation = try #require(
      SbarCommand.parseAsRoot(["validate", "--config", "/tmp/check.json"]) as? ValidateCommand
    )
    #expect(validation.config == "/tmp/check.json")

    #expect(throws: (any Error).self) {
      try SbarCommand.parseAsRoot(["query", "--diagnostics", "--displays"])
    }
    #expect(throws: (any Error).self) { try SbarCommand.parseAsRoot(["validate", "--config="]) }

    let diagnostics = try #require(
      SbarCommand.parseAsRoot(["query", "--diagnostics"]) as? QueryCommand
    )
    #expect(diagnostics.diagnostics)

    let displays = try #require(SbarCommand.parseAsRoot(["query", "--displays"]) as? QueryCommand)
    #expect(displays.displays)

    #expect(try SbarCommand.parseAsRoot(["query"]) is QueryCommand)
    #expect(try SbarCommand.parseAsRoot(["reload"]) is ReloadCommand)
    #expect(try SbarCommand.parseAsRoot(["subscribe"]) is SubscribeCommand)

    let query = try #require(
      SbarCommand.parseAsRoot(["query", "--socket", "/tmp/test.sock"]) as? QueryCommand
    )
    #expect(query.options.socket == "/tmp/test.sock")

    let trigger = try #require(
      SbarCommand.parseAsRoot(["trigger", "refresh", "{} "]) as? TriggerCommand
    )
    #expect(trigger.event == "refresh")

    let set = try #require(
      SbarCommand.parseAsRoot(["set", "clock", "enabled", "false"]) as? SetCommand
    )
    #expect(set.itemID == "clock")
    #expect(set.value == "false")
  }
}
