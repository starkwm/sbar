import Foundation

public enum ConfigurationPath {
  public static func defaultURL(
    directory: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/sbar")
  ) -> URL {
    let jsonc = directory.appending(path: "config.jsonc")

    return FileManager.default.fileExists(atPath: jsonc.path)
      ? jsonc : directory.appending(path: "config.json")
  }
}
