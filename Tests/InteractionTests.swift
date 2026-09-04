import Testing

@testable import sbar

struct InteractionTests {
  @Test("Commands capture output and exit status")
  func command() async throws {
    let result = try await CommandRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "printf hello; exit 7"]
    )
    #expect(result.output == "hello")
    #expect(result.status == 7)
  }

  @Test("Timeout and output limits stop commands")
  func limits() async {
    await #expect(throws: (any Error).self) {
      try await CommandRunner.run(
        executable: "/bin/sh",
        arguments: ["-c", "sleep 10"],
        timeout: 0.05
      )
    }
    await #expect(throws: (any Error).self) {
      try await CommandRunner.run(executable: "/usr/bin/yes", arguments: [])
    }
  }

  @Test("Overflow preserves priority and original display order")
  func overflow() {
    let items: [ItemConfiguration] = [
      .init(id: "a", type: .text), .init(id: "b", type: .text, priority: 10),
      .init(id: "c", type: .text),
    ]
    #expect(
      OverflowSelection.visible(
        items: items,
        widths: ["a": 40, "b": 40, "c": 40],
        available: 80,
        spacing: 5
      ) == ["b"]
    )
  }

  @Test("Disabled groups do not activate child providers")
  func disabledGroup() {
    let group = ItemConfiguration(
      id: "g",
      type: .group,
      enabled: false,
      children: [.init(id: "app", type: .frontApplication)]
    )
    #expect(ItemSections(left: [group]).active.isEmpty)
  }
}
