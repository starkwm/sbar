import ArgumentParser
import Foundation
import SbarCore

struct StartCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start the status bar."
  )

  @Option(name: .long, help: "Configuration file path.", completion: .file())
  var config: String?

  var configurationURL: URL {
    config.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath).standardizedFileURL }
      ?? FileManager.default.homeDirectoryForCurrentUser.appending(
        path: ".config/sbar/config.json"
      )
  }

  mutating func validate() throws {
    if config?.isEmpty == true { throw ValidationError("Configuration path must not be empty.") }
  }

  mutating func run() {
    MainActor.assumeIsolated { SbarApp.run(configurationURL: configurationURL) }
  }
}
