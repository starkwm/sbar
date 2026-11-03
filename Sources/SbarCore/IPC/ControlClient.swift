import Darwin
import Foundation
import StarkIPC

public enum ControlClient {
  public static func agentAdapterURL() throws -> URL {
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

  public static func run(_ request: ControlRequest, socketPath: String) throws {
    let streaming = request.command == "subscribe"
    let client = try SocketClient(path: socketPath, serviceName: "sbar", streaming: streaming)
    try client.send(request)

    while true {
      let line = try client.receiveLine()
      let response = try JSONDecoder().decode(ControlResponse.self, from: line)
      print(String(decoding: line, as: UTF8.self))
      fflush(stdout)

      if !response.ok { exit(1) }
      if !streaming { return }
    }
  }
}
