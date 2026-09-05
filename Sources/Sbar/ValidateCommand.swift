import ArgumentParser
import Foundation
import SbarCore

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate a configuration file without starting the bar."
  )

  @Option(name: .long, help: "Configuration file path.", completion: .file())
  var config = "~/.config/starkbar/config.json"

  mutating func validate() throws {
    if config.isEmpty { throw ValidationError("Configuration path must not be empty.") }
  }

  mutating func run() throws {
    let url = URL(fileURLWithPath: (config as NSString).expandingTildeInPath)
    try ConfigurationValidation.validate(url: url)
    print("Configuration is valid.")
  }
}
