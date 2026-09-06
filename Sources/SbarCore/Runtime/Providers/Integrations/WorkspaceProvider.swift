import Foundation

struct WorkspaceProvider {
  static func executable(_ name: String) -> String? {
    let paths =
      (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init) + [
        "/opt/homebrew/bin", "/usr/local/bin",
      ]

    return paths.map { $0 + "/" + name }.first { FileManager.default.isExecutableFile(atPath: $0) }
  }
}
