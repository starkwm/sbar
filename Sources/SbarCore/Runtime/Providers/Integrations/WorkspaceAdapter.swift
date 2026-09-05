import Foundation

struct WorkspaceAdapter {
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

  static func query(_ type: ItemType) async throws -> String {
    let name = type == .aerospace ? "aerospace" : "yabai"
    guard let path = executable(name) else { return "\(name) not installed" }
    let arguments =
      type == .aerospace
      ? ["list-workspaces", "--focused"] : ["-m", "query", "--spaces", "--space"]
    let result = try await ProcessRunner.run(executable: path, arguments: arguments, timeout: 2)
    guard result.status == 0 else { return "\(name) unavailable" }
    return type == .aerospace ? result.output : try yabaiLabel(Data(result.output.utf8))
  }
}
