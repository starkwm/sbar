import ArgumentParser
import Foundation
import SbarCore

struct StopCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "stop",
    abstract: "Stop the running bar."
  )

  @OptionGroup var options: SocketOptions

  mutating func run() throws { try options.send(ControlRequest(command: "stop")) }
}
