import ArgumentParser
import Foundation
import SbarCore

struct TriggerCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "trigger",
    abstract: "Trigger an event with optional JSON."
  )

  @OptionGroup var options: SocketOptions

  @Argument var event: String
  @Argument var json: String?

  mutating func run() throws {
    let value = try json.map { try JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) }

    try options.send(ControlRequest(command: "trigger", arguments: [event], value: value))
  }
}
