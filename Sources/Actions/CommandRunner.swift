import Darwin
import Foundation

struct CommandResult: Sendable {
    let output: String
    let status: Int32
}

enum CommandFailure: Error, LocalizedError {
    case launch(Int32), exitStatus(Int32), timeout, outputLimit, cancelled

    var errorDescription: String? {
        switch self {
        case let .launch(code): "Could not launch command (\(code))."
        case let .exitStatus(code): "Process exited with status \(code)."
        case .timeout: "Command timed out."
        case .outputLimit: "Command exceeded 64 KB of output."
        case .cancelled: "Command cancelled."
        }
    }
}

struct CommandRunner {
    static func run(executable: String, arguments: [String], timeout: Double = 5) async throws -> CommandResult {
        let worker = Task.detached { try execute(executable: executable, arguments: arguments, timeout: timeout) }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func execute(executable: String, arguments: [String], timeout: Double) throws -> CommandResult {
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else { throw CommandFailure.launch(errno) }
        defer { close(descriptors[0]); close(descriptors[1]) }
        fcntl(descriptors[0], F_SETFL, O_NONBLOCK)
        fcntl(descriptors[0], F_SETFD, FD_CLOEXEC)
        fcntl(descriptors[1], F_SETFD, FD_CLOEXEC)
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, descriptors[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, descriptors[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&actions, descriptors[0])
        posix_spawn_file_actions_addclose(&actions, descriptors[1])
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&attributes, 0)
        let strings = ([executable] + arguments).map { strdup($0) }
        defer { strings.forEach { free($0) } }
        let environment = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") }
        defer { environment.forEach { free($0) } }
        var argv = strings + [nil]
        var envp = environment + [nil]
        var pid: pid_t = 0
        let result = posix_spawn(&pid, executable, &actions, &attributes, &argv, &envp)
        guard result == 0 else { throw CommandFailure.launch(result) }
        // Close our writer immediately; the child owns the duplicated stdout/stderr descriptors.
        close(descriptors[1])
        descriptors[1] = -1
        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        var status: Int32 = 0
        var finished = false
        defer {
            // Includes shell children that inherited the command's process group.
            kill(-pid, SIGKILL)
            if !finished { while waitpid(pid, &status, 0) < 0 && errno == EINTR {} }
        }
        while true {
            if Task.isCancelled { throw CommandFailure.cancelled }
            if ContinuousClock.now >= deadline { throw CommandFailure.timeout }
            let count = read(descriptors[0], &buffer, buffer.count)
            if count > 0 {
                output.append(contentsOf: buffer.prefix(count))
                if output.count > 65_536 { throw CommandFailure.outputLimit }
                continue
            }
            if !finished {
                let waited = waitpid(pid, &status, WNOHANG)
                finished = waited == pid
                if waited < 0 && errno != EINTR { throw CommandFailure.launch(errno) }
            }
            if finished {
                let exitStatus = status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
                return CommandResult(output: String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), status: exitStatus)
            }
            usleep(10_000)
        }
    }
}
