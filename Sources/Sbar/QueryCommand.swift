import ArgumentParser
import Foundation
import SbarCore

struct QueryCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "query",
    abstract: "Query the running bar."
  )
  @OptionGroup var options: SocketOptions

  mutating func run() throws { try options.send(ControlRequest(command: "query")) }
}
