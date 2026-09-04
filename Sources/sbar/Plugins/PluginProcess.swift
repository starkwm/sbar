import Darwin
import Foundation

struct PluginProcess {
  static func run(
    configuration: PluginConfiguration,
    mailbox: PluginMailbox,
    output: @escaping @Sendable (String) -> Void
  ) async throws {
    let task = Task.detached {
      try execute(configuration: configuration, mailbox: mailbox, output: output)
    }
    try await withTaskCancellationHandler {
      try await task.value
    } onCancel: {
      task.cancel()
    }
  }

  private static func execute(
    configuration: PluginConfiguration,
    mailbox: PluginMailbox,
    output: @escaping @Sendable (String) -> Void
  ) throws {
    var input: [Int32] = [0, 0]
    var stdout: [Int32] = [0, 0]
    guard pipe(&input) == 0 else { throw CommandFailure.launch(errno) }
    defer { input.forEach { close($0) } }
    guard pipe(&stdout) == 0 else { throw CommandFailure.launch(errno) }
    defer { stdout.forEach { close($0) } }
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
    defer { strings.forEach { free($0) } }
    let environment = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") }
    defer { environment.forEach { free($0) } }
    var argv = strings + [nil]
    var envp = environment + [nil]
    var pid: pid_t = 0
    let result = posix_spawn(&pid, configuration.executable, &actions, &attributes, &argv, &envp)
    guard result == 0 else { throw CommandFailure.launch(result) }
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
    var pendingOutput = Data()
    var pendingInput = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while !Task.isCancelled {
      if pendingInput.isEmpty { pendingInput = mailbox.take() ?? Data() }
      if !pendingInput.isEmpty {
        let count = pendingInput.withUnsafeBytes { write(input[1], $0.baseAddress, $0.count) }
        if count > 0 {
          pendingInput.removeFirst(count)
        } else if count < 0 && errno != EAGAIN && errno != EINTR {
          pendingInput.removeAll()
        }
      }
      let count = read(stdout[0], &buffer, buffer.count)
      if count > 0 {
        pendingOutput.append(contentsOf: buffer.prefix(count))
        guard pendingOutput.count <= 65_536 else { throw CommandFailure.outputLimit }
        var latest: String?
        while let newline = pendingOutput.firstIndex(of: 10) {
          let message = try JSONDecoder().decode(
            PluginOutput.self,
            from: pendingOutput.prefix(upTo: newline)
          )
          latest = String(message.text.prefix(4096))
          pendingOutput.removeSubrange(...newline)
        }
        if let latest { output(latest) }
      }
      let result = waitpid(pid, &status, WNOHANG)
      if result == pid { exited = true }
      if exited && count <= 0 {
        if !pendingOutput.isEmpty { throw CommandFailure.launch(EPROTO) }
        if status != 0 {
          throw CommandFailure.exitStatus(
            status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
          )
        }
        return
      }
      if result < 0 && !exited && errno != EINTR { throw CommandFailure.launch(errno) }
      usleep(10_000)
    }
    throw CommandFailure.cancelled
  }
}
