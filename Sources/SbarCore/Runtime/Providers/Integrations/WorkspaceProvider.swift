import Foundation

struct WorkspaceProvider {
  static func executable(_ name: String) -> String? {
    let paths =
      (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init) + [
        "/opt/homebrew/bin", "/usr/local/bin",
      ]

    return paths.map { $0 + "/" + name }.first { FileManager.default.isExecutableFile(atPath: $0) }
  }

  static func yabaiLabel(_ data: Data) throws -> String {
    struct Space: Decodable {
      let index: Int
      let label: String?
    }

    let space = try JSONDecoder().decode(Space.self, from: data)

    return space.label.flatMap { $0.isEmpty ? nil : $0 } ?? String(space.index)
  }

  static func queryYabai() async throws -> String {
    guard let path = executable("yabai") else { return "yabai not installed" }
    let result = try await ProcessRunner.run(
      executable: path,
      arguments: ["-m", "query", "--spaces", "--space"],
      timeout: 2
    )
    guard result.exitCode == 0 else { return "yabai unavailable" }
    return try yabaiLabel(Data(result.output.utf8))
  }
}
