import ArgumentParser
import Foundation
import SbarCore

struct SbarCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sbar",
    abstract: "A configurable status bar for macOS.",
    version: "sbar version \(Version.current.value)",
    subcommands: [
      AgentsCommand.self, StartCommand.self, QueryCommand.self, ReloadCommand.self,
      SubscribeCommand.self, TriggerCommand.self, PomodoroCommand.self, SetCommand.self,
      StopCommand.self, ValidateCommand.self, RemindersCommand.self,
    ],
    defaultSubcommand: StartCommand.self
  )
}
