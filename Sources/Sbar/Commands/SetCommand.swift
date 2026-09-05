import ArgumentParser
import Foundation
import SbarCore

struct SetCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "set",
    abstract: "Set an item's property."
  )
  @OptionGroup var options: SocketOptions
  @Argument var itemID: String
  @Argument var property: String
  @Argument var value: String

  mutating func run() throws {
    let decoded =
      (try? JSONDecoder().decode(JSONValue.self, from: Data(value.utf8))) ?? .string(value)
    try options.send(ControlRequest(command: "set", arguments: [itemID, property], value: decoded))
  }
}
