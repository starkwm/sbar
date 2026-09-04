import ControlProtocol
import Darwin
import Foundation

func main() throws {
    var arguments = Array(CommandLine.arguments.dropFirst())
    var path = LocalSocket.defaultPath
    if arguments.first == "--socket" {
        guard arguments.count >= 3 else { throw SocketFailure.message("--socket requires a path and command") }
        path = arguments[1]
        arguments.removeFirst(2)
    }
    guard let command = arguments.first, command != "--help" else {
        print("barctl [--socket path] query|reload|subscribe|trigger <event> [json]|set <item-id> <property> <value>")
        return
    }
    arguments.removeFirst()
    var request = ControlRequest(command: command, arguments: arguments)
    switch command {
    case "query", "reload", "subscribe":
        guard arguments.isEmpty else { throw SocketFailure.message("Unexpected arguments.") }
    case "trigger":
        guard (1...2).contains(arguments.count) else { throw SocketFailure.message("trigger requires an event and optional JSON") }
        request.arguments = [arguments[0]]
        if arguments.count == 2 { request.value = try JSONDecoder().decode(JSONValue.self, from: Data(arguments[1].utf8)) }
    case "set":
        guard arguments.count == 3 else { throw SocketFailure.message("set requires item, property and value") }
        request.arguments = Array(arguments.prefix(2))
        request.value = (try? JSONDecoder().decode(JSONValue.self, from: Data(arguments[2].utf8))) ?? .string(arguments[2])
    default: throw SocketFailure.message("Unknown command: \(command)")
    }
    let fd = try LocalSocket.connect(path: path)
    defer { close(fd) }
    var timeout = timeval(tv_sec: 5, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    if command != "subscribe" { setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) }
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
            if command != "subscribe" { return }
        }
    }
}

do { try main() } catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
