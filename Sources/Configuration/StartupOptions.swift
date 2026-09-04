import Foundation

struct StartupOptions {
  let configurationURL: URL

  static func parse(
    _ arguments: [String],
    home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) throws -> StartupOptions {
    var path: String?
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      if argument == "--config" {
        guard path == nil, index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else {
          throw ConfigurationError.invalidStyle(
            path: "--config",
            reason: "Supply one configuration path."
          )
        }
        path = arguments[index + 1]
        index += 1
      } else if argument.hasPrefix("--config=") {
        guard path == nil else {
          throw ConfigurationError.invalidStyle(path: "--config", reason: "Supply only one path.")
        }
        path = String(argument.dropFirst(9))
      }
      index += 1
    }
    if let path, path.isEmpty {
      throw ConfigurationError.invalidStyle(path: "--config", reason: "Path must not be empty.")
    }
    let url =
      path.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath).standardizedFileURL }
      ?? home.appending(path: ".config/starkbar/config.json")
    return StartupOptions(configurationURL: url)
  }
}
