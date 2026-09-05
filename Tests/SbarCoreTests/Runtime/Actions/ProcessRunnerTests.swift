import Testing

@testable import SbarCore

@Suite("ProcessRunner")
struct ProcessRunnerTests {
  @Test("ProcessRunner.run: captures command output and exit status")
  func runCapturesCommandOutputAndExitStatus() async throws {
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
}
