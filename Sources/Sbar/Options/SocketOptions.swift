import ArgumentParser
import Darwin
import Foundation
import SbarCore

struct SocketOptions: ParsableArguments {
  @Option(name: .long, help: "Control socket path.", completion: .file())
  var socket = NSHomeDirectory() + "/.config/sbar/control.sock"

  func send(_ request: ControlRequest) throws {
    try ControlClient.run(request, socketPath: socket) { response, line in
      try Self.write(response, line: line, to: stdout)
    }
  }

  static func write(_ response: ControlResponse, line: Data, to output: UnsafeMutablePointer<FILE>)
    throws
  {
    _ = line.withUnsafeBytes { fwrite($0.baseAddress, 1, $0.count, output) }
    fputc(10, output)
    fflush(output)

    if !response.ok { throw ExitCode.failure }
  }
}
