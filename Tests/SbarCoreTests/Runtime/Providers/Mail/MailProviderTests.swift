import Testing

@testable import SbarCore

@Suite("Mail provider")
@MainActor
struct MailProviderTests {
  @Test("failed and malformed reads never become zero unread")
  func results() {
    #expect(
      SystemMailReader.state(count: 0, error: nil) == MailState(status: .available, unreadCount: 0)
    )
    #expect(SystemMailReader.state(count: 12, error: nil).hasUnread)
    #expect(SystemMailReader.state(count: -1, error: nil).status == .unavailable)
    #expect(SystemMailReader.state(count: nil, error: nil).unreadCount == nil)
    #expect(SystemMailReader.state(count: 0, error: -1743).status == .unauthorized)
    #expect(SystemMailReader.state(count: 0, error: -1712).status == .unavailable)
    let item = Item(id: "mail", type: .mail)
    #expect(MailState(status: .closed).presentation(for: item).text == "Mail closed")
    #expect(
      MailState(status: .available, unreadCount: 0).presentation(for: item).accessibilityLabel
        == "Inbox, 0 unread"
    )
  }

  @Test("polling updates the runtime and stops when the item is removed")
  func lifecycle() async throws {
    var reads = 0
    let provider = MailProvider(interval: .milliseconds(10)) {
      reads += 1
      return MailState(status: .available, unreadCount: reads)
    }
    let runtime = ProviderRuntime(mail: provider)
    defer { runtime.stop() }
    let item = Item(id: "mail", type: .mail, refresh: .init(mode: .event))
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    try await Task.sleep(for: .milliseconds(100))
    #expect(reads > 1)
    #expect(runtime.presentation(for: item)?.text == "\(reads) unread")
    runtime.configure(Configuration(bar: .init(), items: .init()))
    let stopped = reads
    try await Task.sleep(for: .milliseconds(50))
    #expect(reads == stopped)
  }

  @Test("an in-flight read cannot publish after stop or restart")
  func cancellation() async throws {
    var reads = 0
    var updates: [MailState] = []
    let provider = MailProvider {
      reads += 1
      let count = reads
      // Simulates an Apple Event that finishes even after cancellation.
      await Task.detached { try? await Task.sleep(for: .milliseconds(60)) }.value
      return MailState(status: .available, unreadCount: count)
    }
    defer { provider.stop() }
    provider.start { updates.append($0) }
    try await Task.sleep(for: .milliseconds(20))
    provider.start { updates.append($0) }
    try await Task.sleep(for: .milliseconds(100))
    #expect(updates.map(\.unreadCount) == [2])
  }
}
