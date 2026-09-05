import Testing

@testable import SbarCore

@Suite("Interaction")
struct InteractionTests {
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

  @Test("OverflowSelection.visibleItemIDs: preserves priority under constrained width")
  func visibleItemIDsPreservesPriorityUnderConstrainedWidth() {
    let items: [ItemConfiguration] = [
      .init(id: "a", type: .text), .init(id: "b", type: .text, priority: 10),
      .init(id: "c", type: .text),
    ]

    #expect(
      OverflowSelection.visibleItemIDs(
        items: items,
        widths: ["a": 40, "b": 40, "c": 40],
        available: 80,
        spacing: 5
      ) == ["b"]
    )
  }

  @Test("ItemSections.active: excludes children of disabled groups")
  func activeExcludesChildrenOfDisabledGroups() {
    let group = ItemConfiguration(
      id: "g",
      type: .group,
      enabled: false,
      children: [.init(id: "app", type: .frontApplication)]
    )

    #expect(ItemSections(left: [group]).active.isEmpty)
  }
}
