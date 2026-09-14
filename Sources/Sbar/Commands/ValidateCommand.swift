import ArgumentParser
import Foundation
import SbarCore

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate a configuration file without starting the bar."
  )

  @Option(name: .long, help: "Configuration file path.", completion: .file())
  var config: String?

  var configurationURL: URL {
    config.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath).standardizedFileURL }
      ?? ConfigurationPath.defaultURL()
  }

  mutating func validate() throws {
    if config?.isEmpty == true { throw ValidationError("Configuration path must not be empty.") }
  }

  mutating func run() throws {
    try ConfigurationValidator.validate(url: configurationURL)

    print("Configuration is valid.")
  }
}
