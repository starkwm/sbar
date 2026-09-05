import ArgumentParser
import Foundation
import SbarCore

struct SubscribeCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "subscribe",
    abstract: "Stream bar events."
  )
  @OptionGroup var options: SocketOptions

  mutating func run() throws { try options.send(ControlRequest(command: "subscribe")) }
}
