import ArgumentParser
import Foundation
import SbarCore

struct ReloadCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reload",
    abstract: "Reload the configuration."
  )

  @OptionGroup var options: SocketOptions

  mutating func run() throws { try options.send(ControlRequest(command: "reload")) }
}
