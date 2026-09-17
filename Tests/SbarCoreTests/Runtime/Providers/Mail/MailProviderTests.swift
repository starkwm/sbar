import Foundation
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
    #expect(reads == 1)
    #expect(runtime.presentation(for: item)?.text == "\(reads) unread")
    runtime.configure(Configuration(bar: .init(), items: .init()))
    let stopped = reads
    try await Task.sleep(for: .milliseconds(50))
    #expect(reads == stopped)
  }

  @Test("shared interval follows enabled items and config reloads")
  func intervals() {
    let provider = MailProvider { MailState() }
    let runtime = ProviderRuntime(mail: provider)
    defer { runtime.stop() }
    var first = Item(id: "first", type: .mail, mail: .init(pollInterval: 60))
    let second = Item(id: "second", type: .mail)
    let disabled = Item(
      id: "disabled",
      type: .mail,
      enabled: false,
      mail: .init(pollInterval: 5)
    )
    func configure(_ items: [Item]) {
      runtime.configure(Configuration(bar: .init(), items: .init(right: items)))
    }
    configure([first, second, disabled])
    #expect(provider.interval == .seconds(30))
    first.mail?.pollInterval = 10
    configure([first, second, disabled])
    #expect(provider.interval == .seconds(10))
    configure([second])
    #expect(provider.interval == .seconds(30))
    configure([disabled])
    configure([first])
    #expect(provider.interval == .seconds(10))
  }

  @Test("provider repeats queries at its supplied interval")
  func polling() async throws {
    var reads = 0
    let provider = MailProvider(interval: .milliseconds(10)) {
      reads += 1
      return MailState()
    }
    defer { provider.stop() }
    provider.start { _ in }
    try await Task.sleep(for: .milliseconds(100))
    #expect(reads > 1)
  }

  @Test("mail settings decode, round trip, and validate")
  func configuration() throws {
    for settings in [
      "", #","mail":{}"#, #","mail":{"pollInterval":5}"#,
      #","mail":{"pollInterval":10.5}"#,
    ] {
      let item = try JSONDecoder().decode(
        Item.self,
        from: Data(("{\"id\":\"mail\",\"type\":\"mail\"" + settings + "}").utf8)
      )
      try Configuration(bar: .init(), items: .init(right: [item])).validate()
      #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
      #expect((item.mail ?? MailConfiguration()).resolvedPollInterval >= 5)
    }
    #expect(MailConfiguration().resolvedPollInterval == 30)
    for interval in [0, 4.9, -1, Double.infinity, Double.nan] {
      let item = Item(id: "mail", type: .mail, mail: .init(pollInterval: interval))
      #expect(throws: ConfigurationError.self) {
        try Configuration(bar: .init(), items: .init(right: [item])).validate()
      }
    }
    let wrongType = Item(id: "text", type: .text, mail: .init(pollInterval: 10))
    #expect(throws: ConfigurationError.self) {
      try Configuration(bar: .init(), items: .init(right: [wrongType])).validate()
    }
  }

  @Test("an in-flight read cannot publish after stop or restart")
  func cancellation() async throws {
    var reads = 0
    var updates: [MailState] = []
    var suspended: CheckedContinuation<MailState, Never>?
    let provider = MailProvider {
      reads += 1
      // Simulates an Apple Event that finishes even after cancellation.
      if reads == 1 { return await withCheckedContinuation { suspended = $0 } }
      return MailState(status: .available, unreadCount: reads)
    }
    defer {
      suspended?.resume(returning: MailState(status: .available, unreadCount: 1))
      provider.stop()
    }
    provider.start { updates.append($0) }
    try await waitUntil { suspended != nil }
    provider.start { updates.append($0) }
    try await waitUntil { !updates.isEmpty }
    suspended?.resume(returning: MailState(status: .available, unreadCount: 1))
    suspended = nil
    try await Task.sleep(for: .milliseconds(50))
    #expect(updates.map(\.unreadCount) == [2])
  }
}
