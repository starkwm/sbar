import Darwin
import Foundation
import StarkIPC

public enum ControlClient {
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
