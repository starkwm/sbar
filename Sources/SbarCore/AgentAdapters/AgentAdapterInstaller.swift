import Foundation

public enum AgentAdapterInstaller {
  public static func install() throws -> URL {
    let directory = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: ".cache/sbar/adapters", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    try AgentAdapterScripts.pi.write(
      to: directory.appending(path: "pi.ts"),
      atomically: true,
      encoding: .utf8
    )
    let adapter = directory.appending(path: "adapter.sh")
    try AgentAdapterScripts.adapter.write(to: adapter, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: adapter.path)
    return adapter
  }
}
