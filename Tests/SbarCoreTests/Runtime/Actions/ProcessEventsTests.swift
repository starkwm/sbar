import Darwin
import Foundation
import Testing

@testable import SbarCore

@Suite("ProcessEvents")
struct ProcessEventsTests {
  @Test("wait: distinguishes process exit from a worker wake")
  func processExitNotification() throws {
    let events = try ProcessEvents()
    events.wake()
    #expect(try events.wait(read: nil, timeout: .seconds(2)) == .ready)

    var input: [Int32] = [0, 0]
    try #require(pipe(&input) == 0)
    defer { for descriptor in input where descriptor >= 0 { close(descriptor) } }

    var actions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_adddup2(&actions, input[0], STDIN_FILENO)
    for descriptor in input { posix_spawn_file_actions_addclose(&actions, descriptor) }

    let command = ["/bin/sh", "-c", "read value; exit 7"]
    let arguments = command.map { strdup($0) }
    defer { for argument in arguments { free(argument) } }
    var argv = arguments + [nil]
    var envp: [UnsafeMutablePointer<CChar>?] = [nil]
    var pid: pid_t = 0
    let result = posix_spawn(&pid, "/bin/sh", &actions, nil, &argv, &envp)
    try #require(result == 0)
    var status: Int32 = 0
    var reaped = false
    defer {
      if !reaped {
        kill(pid, SIGKILL)
        while waitpid(pid, &status, 0) < 0 && errno == EINTR {}
      }
    }

    // Keep the shell alive until the exit watch is installed.
    try events.watch(process: pid)
    close(input[1])
    input[1] = -1

    #expect(try events.wait(read: nil, timeout: .seconds(2)) == .processExited)
    var waited: pid_t
    repeat { waited = waitpid(pid, &status, 0) } while waited < 0 && errno == EINTR
    reaped = waited == pid
    #expect(reaped)
    #expect(status == 7 << 8)
  }
}
