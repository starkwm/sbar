import Darwin
import Foundation
import StarkIPC

public enum LocalSocket {
  public static var defaultPath: String { NSHomeDirectory() + "/.config/sbar/control.sock" }

  public static func address<T>(
    _ path: String,
    body: (UnsafePointer<sockaddr>, socklen_t) throws -> T
  ) throws -> T {
    try StarkIPC.LocalSocket.address(path, body: body)
  }

  public static func connect(path: String) throws -> Int32 {
    try StarkIPC.LocalSocket.connect(path: path, serviceName: "sbar")
  }

  public static func send(_ data: Data, to fd: Int32) throws {
    try StarkIPC.LocalSocket.send(data, to: fd)
  }
}
