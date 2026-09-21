import Testing

@testable import SbarCore

@Suite("ProcessRunner")
struct ProcessRunnerTests {
  @Test("ProcessRunner.run: captures command output and exit status")
  func outputAndExitStatus() async throws {
    let result = try await ProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "printf hello; exit 7"]
    )

    #expect(result.output == "hello")
    #expect(result.exitCode == 7)
  }

  @Test("ProcessRunner.run: stops commands that exceed timeout or output limits")
  func runStopsCommandsExceedingLimits() async {
    await #expect(throws: (any Error).self) {
      try await ProcessRunner.run(
        executable: "/bin/sh",
        arguments: ["-c", "sleep 10"],
        timeout: 0.05
      )
    }

    await #expect(throws: (any Error).self) {
      try await ProcessRunner.run(executable: "/usr/bin/yes", arguments: [])
    }
  }
  @Test("ProcessRunner.run: cancellation wakes a quiet command", .timeLimit(.minutes(1)))
  func runCancelsQuietCommand() async throws {
    let task = Task {
      try await ProcessRunner.run(executable: "/bin/sh", arguments: ["-c", "sleep 10"])
    }
    try await Task.sleep(for: .milliseconds(50))
    let start = ContinuousClock.now
    task.cancel()
    await #expect(throws: (any Error).self) { try await task.value }

    #expect(start.duration(to: .now) < .seconds(1))
  }

  @Test("ProcessRunner.run: observes exit without waiting for inherited pipe writers")
  func inheritedOutput() async throws {
    let start = ContinuousClock.now
    let result = try await ProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "sleep 10 & sleep 0.05; exit 7"]
    )

    #expect(result.exitCode == 7)
    #expect(start.duration(to: .now) < .seconds(1))
  }

  @Test("ProcessRunner.run: waits for exit after output closes")
  func runWaitsAfterOutputCloses() async throws {
    let result = try await ProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "exec 1>&- 2>&-; sleep 0.05; exit 3"]
    )

    #expect(result.exitCode == 3)
  }

}
