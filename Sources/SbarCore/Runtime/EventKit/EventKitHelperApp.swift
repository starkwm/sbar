import AppKit
import EventKit
import Foundation
import StarkIPC

public enum EventKitHelperApp {
  @MainActor
  public static func run() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = EventKitHelperDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}

@MainActor
private final class EventKitHelperDelegate: NSObject, NSApplicationDelegate {
  private let reminders = SystemRemindersStore()
  private let calendar = SystemCalendarStore()
  private lazy var jobs = EventKitJobs { [weak self] request in
    guard let self else { return EventKitResponse(error: "EventKit helper stopped.") }
    return await self.read(request)
  }
  private var server: SocketServer<EventKitRequest, EventKitResponse>?
  private var observer: NSObjectProtocol?
  private var idle: Task<Void, Never>?
  private var lastRequest = Date()

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      let appURL = Bundle.main.bundleURL
      guard let build = Bundle.main.object(forInfoDictionaryKey: "SbarBuildIdentifier") as? String
      else { throw EventKitHelperError(message: "Missing EventKit helper build identity.") }
      let location = EventKitHelperLocation(app: appURL, build: build)
      try location.prepareDirectory()
      let server = SocketServer<EventKitRequest, EventKitResponse>(
        path: location.socketPath,
        serviceName: "sbar EventKit helper",
        errorResponse: { EventKitResponse(error: $0.localizedDescription) },
        handler: { [weak self] request in
          let response = await self?.handle(request) ?? EventKitResponse(error: "Helper stopped.")
          return SocketReply(response)
        }
      )
      try server.start()
      self.server = server
      observer = NotificationCenter.default.addObserver(
        forName: .EKEventStoreChanged,
        object: nil,
        queue: nil
      ) { @Sendable _ in
        DistributedNotificationCenter.default().postNotificationName(
          EventKitHelperLocation.changeNotification,
          object: location.socketPath,
          userInfo: nil,
          deliverImmediately: true
        )
      }
      idle = Task { [weak self] in
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(30)) } catch { return }
          guard let self else { return }
          self.jobs.expire()
          if self.jobs.isEmpty && Date().timeIntervalSince(self.lastRequest) > 120 {
            NSApp.terminate(nil)
          }
        }
      }
    } catch {
      // A concurrent launcher may already own this build's socket.
      fputs("sbar EventKit helper: \(error.localizedDescription)\n", stderr)
      NSApp.terminate(nil)
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    idle?.cancel()
    jobs.stop()
    if let observer { NotificationCenter.default.removeObserver(observer) }
    server?.stop()
  }

  private func read(_ request: EventKitRequest) async -> EventKitResponse {
    switch request.resource {
    case .lists:
      do { return EventKitResponse(lists: try await reminders.lists()) } catch {
        return EventKitResponse(error: error.localizedDescription)
      }
    case .reminders:
      return EventKitResponse(
        reminders: await reminders.read(listIds: request.listIds, now: Date())
      )
    case .calendar:
      let state = await calendar.read(lookaheadDays: request.lookaheadDays ?? 7, now: Date())
      return EventKitResponse(calendar: state)
    case nil: return EventKitResponse(error: "Missing EventKit resource.")
    }
  }

  private func handle(_ request: EventKitRequest) -> EventKitResponse {
    lastRequest = Date()
    return jobs.handle(request)
  }
}
