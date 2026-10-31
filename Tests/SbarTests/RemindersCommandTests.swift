import Foundation
import SbarCore
import Testing

@testable import Sbar

@Suite("RemindersListsCommand")
@MainActor
struct RemindersCommandTests {
  @Test("output: emits list metadata and an empty JSON array without accessing native data")
  func output() async throws {
    let data = Data(
      #"[{"id":"local-id","title":"Tasks","sourceId":"account","sourceTitle":"Work"}]"#.utf8
    )
    let lists = try JSONDecoder().decode([ReminderList].self, from: data)
    let output = try await RemindersListsCommand.output { lists }
    let decoded = try JSONDecoder().decode([ReminderList].self, from: Data(output.utf8))

    #expect(decoded == lists)
    let empty = try await RemindersListsCommand.output { [] }
    #expect(try JSONDecoder().decode([ReminderList].self, from: Data(empty.utf8)).isEmpty)
  }

  @Test("output: access failures propagate instead of becoming empty success")
  func failure() async {
    struct Denied: Error {}
    do {
      _ = try await RemindersListsCommand.output { throw Denied() }
      Issue.record("Expected access failure")
    } catch { #expect(error is Denied) }
  }
}
