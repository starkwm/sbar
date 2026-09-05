import Darwin
import Foundation

/// All mutable connection state is confined to queue; handlers cross to the main actor explicitly.
final class ControlServer: @unchecked Sendable {
  private struct Connection {
    let id = UUID()
    let source: any DispatchSourceRead
    var data = Data()
    var subscribed = false
    var handling = false
  }

  private let onStop: @Sendable () -> Void
  private let path: String
  private let handler: @Sendable (ControlRequest) async -> ControlResponse
  private let queue = DispatchQueue(label: "starkbar.control")
  private var listener: (any DispatchSourceRead)?
  private var connections: [Int32: Connection] = [:]
  private var lock: Int32 = -1

  init(
    path: String,
    onStop: @escaping @Sendable () -> Void = {},
    handler: @escaping @Sendable (ControlRequest) async -> ControlResponse
  ) {
    self.onStop = onStop
    self.path = path
    self.handler = handler
  }

  func start() throws {
    try queue.sync {
      guard listener == nil else { return }
      let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      lock = open(path + ".lock", O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
      guard lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else {
        if lock >= 0 {
          close(lock)
          lock = -1
        }
        throw SocketFailure.message("Another sbar instance owns the control socket.")
      }
      do {
        var info = stat()
        if lstat(path, &info) == 0 {
          guard info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFSOCK else {
            throw SocketFailure.message(
              "Refusing to replace a non-socket or another user's socket."
            )
          }
          unlink(path)
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketFailure.message("Cannot create control socket.") }
        let status: Int32
        do { status = try LocalSocket.address(path) { bind(fd, $0, $1) } } catch {
          close(fd)
          throw error
        }
        guard status == 0, chmod(path, 0o600) == 0, listen(fd, 16) == 0 else {
          close(fd)
          throw SocketFailure.message("Cannot bind control socket.")
        }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptClients(fd) }
        source.setCancelHandler { close(fd) }
        listener = source
        source.resume()
      } catch {
        close(lock)
        lock = -1
        throw error
      }
    }
  }

  func stop() {
    queue.sync {
      guard listener != nil else { return }
      listener?.cancel()
      listener = nil
      for fd in Array(connections.keys) { disconnect(fd) }
      unlink(path)
      if lock >= 0 {
        close(lock)
        lock = -1
      }
    }
  }

  func publish(_ response: ControlResponse) {
    queue.async { [weak self] in
      guard let self else { return }
      for fd in self.connections.keys.filter({ self.connections[$0]?.subscribed == true }) {
        self.respond(response, to: fd, closeAfter: false)
      }
    }
  }

  private func acceptClients(_ fd: Int32) {
    while true {
      let client = accept(fd, nil, nil)
      guard client >= 0 else { return }
      var uid: uid_t = 0
      var gid: gid_t = 0
      guard connections.count < 32, getpeereid(client, &uid, &gid) == 0, uid == getuid() else {
        close(client)
        continue
      }
      _ = fcntl(client, F_SETFL, O_NONBLOCK)
      _ = fcntl(client, F_SETFD, FD_CLOEXEC)
      var one: Int32 = 1
      setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
      let source = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue)
      source.setEventHandler { [weak self] in self?.readClient(client) }
      source.setCancelHandler { close(client) }
      let connection = Connection(source: source)
      let id = connection.id
      connections[client] = connection
      source.resume()
      queue.asyncAfter(deadline: .now() + 5) { [weak self] in
        guard self?.connections[client]?.id == id, self?.connections[client]?.subscribed == false
        else { return }
        self?.disconnect(client)
      }
    }
  }

  private func readClient(_ fd: Int32) {
    var buffer = [UInt8](repeating: 0, count: 4096)
    let count = recv(fd, &buffer, buffer.count, 0)
    guard count > 0 else {
      if count == 0 || errno != EAGAIN { disconnect(fd) }
      return
    }
    guard connections[fd]?.handling == false else {
      disconnect(fd)
      return
    }
    connections[fd]?.data.append(contentsOf: buffer.prefix(count))
    guard let connection = connections[fd] else { return }
    guard connection.data.count <= 131_072 else {
      disconnect(fd)
      return
    }
    guard let newline = connection.data.firstIndex(of: 10) else { return }
    let id = connection.id
    connections[fd]?.handling = true
    do {
      let request = try JSONDecoder().decode(
        ControlRequest.self,
        from: connection.data.prefix(upTo: newline)
      )
      Task { [weak self, handler] in
        let response = await handler(request)
        self?.queue.async { [weak self] in
          guard let self else { return }
          defer { if request.command == "stop" && response.ok { self.onStop() } }
          guard self.connections[fd]?.id == id else { return }
          self.connections[fd]?.subscribed = request.command == "subscribe" && response.ok
          self.respond(response, to: fd, closeAfter: self.connections[fd]?.subscribed != true)
        }
      }
    } catch { respond(ControlResponse(ok: false, error: error.localizedDescription), to: fd) }
  }

  private func respond(_ response: ControlResponse, to fd: Int32, closeAfter: Bool = true) {
    do {
      var data = try JSONEncoder().encode(response)
      data.append(10)
      // Slow subscribers are disconnected rather than blocking the UI or growing buffers.
      try LocalSocket.send(data, to: fd)
      if closeAfter { disconnect(fd) }
    } catch { disconnect(fd) }
  }

  private func disconnect(_ fd: Int32) { connections.removeValue(forKey: fd)?.source.cancel() }
}
