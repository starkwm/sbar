import Darwin
import Foundation

struct PluginRunner {
  static func run(
    configuration: Plugin,
    mailbox: PluginMailbox,
    output: @escaping @Sendable (PluginOutput) async -> Void
  ) async throws {
    let events = try ProcessEvents()
    let (stream, continuation) = AsyncThrowingStream<PluginOutput, any Error>.makeStream(
      bufferingPolicy: .bufferingNewest(1)
    )
    let task = Task.detached {
      do {
        try execute(configuration: configuration, mailbox: mailbox, events: events) {
          continuation.yield($0)
        }
        continuation.finish()
      } catch { continuation.finish(throwing: error) }
    }
    try await withTaskCancellationHandler {
      defer {
        task.cancel()
        events.wake()
      }

      for try await value in stream {
        try Task.checkCancellation()
        await output(value)
      }

      await task.value
      try Task.checkCancellation()
    } onCancel: {
      task.cancel()
      events.wake()
    }
  }

  private static func execute(
    configuration: Plugin,
    mailbox: PluginMailbox,
    events: ProcessEvents,
    output: @escaping @Sendable (PluginOutput) -> Void
  ) throws {
    var input: [Int32] = [0, 0]
    var stdout: [Int32] = [0, 0]
    guard pipe(&input) == 0 else { throw ProcessError.launch(errno) }

    defer { for descriptor in input { close(descriptor) } }
    guard pipe(&stdout) == 0 else { throw ProcessError.launch(errno) }

    defer { for descriptor in stdout { close(descriptor) } }

    for fd in input + stdout { _ = fcntl(fd, F_SETFD, FD_CLOEXEC) }

    _ = fcntl(stdout[0], F_SETFL, O_NONBLOCK)
    _ = fcntl(input[1], F_SETFL, O_NONBLOCK)
    _ = fcntl(input[1], F_SETNOSIGPIPE, 1)

    var actions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_adddup2(&actions, input[0], STDIN_FILENO)
    posix_spawn_file_actions_adddup2(&actions, stdout[1], STDOUT_FILENO)
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0)

    for fd in input + stdout { posix_spawn_file_actions_addclose(&actions, fd) }

    var attributes: posix_spawnattr_t?
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
    posix_spawnattr_setpgroup(&attributes, 0)

    let strings = ([configuration.executable] + (configuration.arguments ?? [])).map { strdup($0) }
    defer { for string in strings { free(string) } }
    let environment = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") }
    defer { for string in environment { free(string) } }
    var argv = strings + [nil]
    var envp = environment + [nil]

    var pid: pid_t = 0
    let result = posix_spawn(&pid, configuration.executable, &actions, &attributes, &argv, &envp)
    guard result == 0 else { throw ProcessError.launch(result) }

    close(input[0])
    input[0] = -1
    close(stdout[1])
    stdout[1] = -1

    var status: Int32 = 0
    var exited = false
    defer {
      kill(-pid, SIGKILL)

      if !exited { while waitpid(pid, &status, 0) < 0 && errno == EINTR {} }
    }

    try events.watch(process: pid)
    mailbox.setWakeHandler { events.wake() }
    defer { mailbox.setWakeHandler(nil) }

    var pendingInput = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    var outputClosed = false
    var inputClosed = false
    var framer = PluginOutputFramer()

    while !Task.isCancelled {
      var wroteInput = false

      if pendingInput.isEmpty { pendingInput = mailbox.take() ?? Data() }
      if !pendingInput.isEmpty && !inputClosed {
        let count = pendingInput.withUnsafeBytes { write(input[1], $0.baseAddress, $0.count) }

        if count > 0 {
          pendingInput.removeFirst(count)
          wroteInput = true
        } else if count < 0 && errno != EAGAIN && errno != EINTR {
          pendingInput.removeAll()
          inputClosed = true
        }
      }

      let count = outputClosed ? 0 : read(stdout[0], &buffer, buffer.count)

      if count == 0 { outputClosed = true }
      if count < 0 && errno != EAGAIN && errno != EINTR { throw ProcessError.launch(errno) }
      if count > 0 {
        if let latest = try framer.append(Data(buffer.prefix(count))) { output(latest) }
      }

      let result = waitpid(pid, &status, WNOHANG)

      if result == pid { exited = true }
      if exited && count <= 0 {
        try framer.finish()

        if status != 0 {
          throw ProcessError.exitStatus(
            status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
          )
        }

        return
      }

      if result < 0 && !exited && errno != EINTR { throw ProcessError.launch(errno) }

      if count > 0 || wroteInput { continue }
      if Task.isCancelled { break }

      try events.wait(
        read: outputClosed ? nil : stdout[0],
        write: !pendingInput.isEmpty && !inputClosed ? input[1] : nil
      )
    }

    throw ProcessError.cancelled
  }
}
