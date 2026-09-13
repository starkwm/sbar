import AppKit
import Foundation

@MainActor
final class MailProvider {
  private(set) var interval: Duration

  private let read: @MainActor @Sendable () async -> MailState
  private var task: Task<Void, Never>?

  init(
    interval: Duration = .seconds(30),
    read: @escaping @MainActor @Sendable () async -> MailState = SystemMailReader.read
  ) {
    self.interval = interval
    self.read = read
  }

  func start(interval: Duration? = nil, update: @escaping @MainActor (MailState) -> Void) {
    stop()
    if let interval { self.interval = interval }
    let read = read
    let interval = self.interval
    task = Task {
      while !Task.isCancelled {
        let state = await read()
        guard !Task.isCancelled else { return }
        update(state)
        do { try await Task.sleep(for: interval) } catch { return }
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
  }
}

enum SystemMailReader {
  @MainActor
  static func read() async -> MailState {
    guard
      let application = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.mail"
      ).first
    else { return MailState(status: .closed) }
    guard Bundle.main.object(forInfoDictionaryKey: "NSAppleEventsUsageDescription") != nil else {
      return MailState()
    }
    let pid = application.processIdentifier
    return await Task.detached(priority: .utility) { query(pid: pid) }.value
  }

  static func state(count: Int?, error: Int?) -> MailState {
    if let error { return MailState(status: error == -1743 ? .unauthorized : .unavailable) }
    guard let count, count >= 0 else { return MailState() }
    return MailState(status: .available, unreadCount: count)
  }

  private static func property(_ code: AEKeyword, of container: NSAppleEventDescriptor)
    -> NSAppleEventDescriptor?
  {
    let record = NSAppleEventDescriptor.record()
    record.setDescriptor(
      NSAppleEventDescriptor(typeCode: typeProperty),
      forKeyword: AEKeyword(keyAEDesiredClass)
    )
    record.setDescriptor(
      NSAppleEventDescriptor(enumCode: OSType(formPropertyID)),
      forKeyword: AEKeyword(keyAEKeyForm)
    )
    record.setDescriptor(
      NSAppleEventDescriptor(typeCode: code),
      forKeyword: AEKeyword(keyAEKeyData)
    )
    record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
    return record.coerce(toDescriptorType: typeObjectSpecifier)
  }

  private static func query(pid: pid_t) -> MailState {
    // Mail.sdef: inbox = 'inmb', mailbox unread count = 'mbuc'. Target the PID
    // rather than the bundle ID so a query cannot launch Mail after it quits.
    guard let inbox = property(0x696E_6D62, of: NSAppleEventDescriptor.null()),
      let unread = property(0x6D62_7563, of: inbox)
    else { return MailState() }
    let event = NSAppleEventDescriptor(
      eventClass: kAECoreSuite,
      eventID: kAEGetData,
      targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
      returnID: AEReturnID(kAutoGenerateReturnID),
      transactionID: AETransactionID(kAnyTransactionID)
    )
    event.setParam(unread, forKeyword: AEKeyword(keyDirectObject))
    do {
      let reply = try event.sendEvent(options: [.waitForReply, .canInteract], timeout: 10)
      if let error = reply.paramDescriptor(forKeyword: AEKeyword(keyErrorNumber)),
        error.int32Value != 0
      {
        return state(count: nil, error: Int(error.int32Value))
      }
      let count = reply.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.coerce(
        toDescriptorType: typeSInt32
      )
      return state(count: count.map { Int($0.int32Value) }, error: nil)
    } catch {
      return state(count: nil, error: (error as NSError).code)
    }
  }
}
