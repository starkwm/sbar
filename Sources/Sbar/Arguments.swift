import ArgumentParser
import Foundation
import SbarCore

struct Arguments: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sbar",
    abstract: "A configurable status bar for macOS.",
    subcommands: [
      StartCommand.self, QueryCommand.self, ReloadCommand.self, SubscribeCommand.self,
      TriggerCommand.self, SetCommand.self,
    ],
    defaultSubcommand: StartCommand.self
  )
}
