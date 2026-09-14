import ArgumentParser
import Foundation
import SbarCore

struct SbarCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sbar",
    abstract: "A configurable status bar for macOS.",
    version: "sbar version \(Version.current.value)",
    subcommands: [
      StartCommand.self, QueryCommand.self, ReloadCommand.self, SubscribeCommand.self,
      TriggerCommand.self, SetCommand.self, StopCommand.self, ValidateCommand.self,
    ],
    defaultSubcommand: StartCommand.self
  )
}
