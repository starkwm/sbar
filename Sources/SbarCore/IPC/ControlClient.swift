import Foundation
import StarkIPC

public enum ControlClient {
  public static func run(
    _ request: ControlRequest,
    socketPath: String,
    onResponse: (ControlResponse, Data) throws -> Void
  ) throws {
    let streaming = request.command == "subscribe"
    let client = try SocketClient(path: socketPath, serviceName: "sbar", streaming: streaming)
    try client.send(request)

    repeat {
      let line = try client.receiveLine()
      let response = try JSONDecoder().decode(ControlResponse.self, from: line)
      try onResponse(response, line)
    } while streaming
  }
}
