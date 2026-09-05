import Foundation

/// A bounded cross-thread mailbox; the worker is the only reader.
final class PluginMailbox: @unchecked Sendable {
  private let lock = NSLock()
  private var messages: [Data] = []
  private var wakeHandler: (@Sendable () -> Void)?

  func send(_ input: PluginInput) {
    guard var data = try? JSONEncoder().encode(input), data.count <= 65_536 else { return }

    data.append(10)

    lock.lock()
    if messages.count < 32 { messages.append(data) }
    let wake = wakeHandler
    lock.unlock()
    wake?()
  }

  func setWakeHandler(_ handler: (@Sendable () -> Void)?) {
    lock.lock()
    wakeHandler = handler
    lock.unlock()
    handler?()
  }

  func take() -> Data? {
    lock.lock()
    defer { lock.unlock() }

    return messages.isEmpty ? nil : messages.removeFirst()
  }
}
