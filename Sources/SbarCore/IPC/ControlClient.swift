import Darwin
import Foundation

public enum ControlClient {
  public static func run(_ request: ControlRequest, socketPath: String) throws {
    let fd = try LocalSocket.connect(path: socketPath)
    defer { close(fd) }
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    if request.command != "subscribe" {
      setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    }
    var data = try JSONEncoder().encode(request)
    data.append(10)
    try LocalSocket.send(data, to: fd)
    var pending = Data()
    var buffer = [UInt8](repeating: 0, count: 8192)
    while true {
      let count = recv(fd, &buffer, buffer.count, 0)
      guard count > 0 else { throw SocketFailure.message("Connection closed or timed out.") }
      pending.append(contentsOf: buffer.prefix(count))
      guard pending.count <= 1_048_576 else { throw SocketFailure.message("Response too large.") }
      while let newline = pending.firstIndex(of: 10) {
        let line = pending.prefix(upTo: newline)
        let response = try JSONDecoder().decode(ControlResponse.self, from: line)
        print(String(decoding: line, as: UTF8.self))
        fflush(stdout)
        pending.removeSubrange(...newline)
        if !response.ok { exit(1) }
        if request.command != "subscribe" { return }
      }
    }
  }
}
