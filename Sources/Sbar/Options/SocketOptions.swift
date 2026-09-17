import ArgumentParser
import Foundation
import SbarCore

struct SocketOptions: ParsableArguments {
  @Option(name: .long, help: "Control socket path.", completion: .file())
  var socket = NSHomeDirectory() + "/.config/sbar/control.sock"

  func send(_ request: ControlRequest) throws {
    try ControlClient.run(request, socketPath: socket)
  }
}
