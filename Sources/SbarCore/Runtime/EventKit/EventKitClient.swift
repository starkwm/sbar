import AppKit
import EventKit
import Foundation
import StarkIPC

@MainActor
final class EventKitClient {
  static let shared = EventKitClient()

  nonisolated static func exchange(
    _ request: EventKitRequest,
    path: String
  ) async throws -> EventKitResponse {
    try await Task.detached {
      let client = try SocketClient(path: path, serviceName: "sbar EventKit helper")
      try client.send(request)
      return try client.receive(EventKitResponse.self)
    }.value
  }

  private let locate: @MainActor () throws -> EventKitHelperLocation
  private let transport: @Sendable (EventKitRequest, String) async throws -> EventKitResponse
  private let open: @MainActor (URL) async throws -> Void
  private var launch: Task<Void, any Error>?
  private var observer: NSObjectProtocol?
  private var observedPath: String?

  init(
    locate: @escaping @MainActor () throws -> EventKitHelperLocation = {
      guard let executable = Bundle.main.executableURL else {
        throw EventKitHelperError(message: "Cannot locate the sbar executable.")
      }
      return try EventKitHelperLocation.resolve(executable: executable)
    },
    transport: @escaping @Sendable (EventKitRequest, String) async throws -> EventKitResponse = {
      try await EventKitClient.exchange($0, path: $1)
    },
    open: @escaping @MainActor (URL) async throws -> Void = { app in
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = false
      configuration.addsToRecentItems = false
      configuration.createsNewApplicationInstance = true
      _ = try await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
    }
  ) {
    self.locate = locate
    self.transport = transport
    self.open = open
  }

  isolated deinit {
    if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
  }

  func request(
    _ resource: EventKitRequest.Resource,
    listIds: Set<String>? = nil,
    lookaheadDays: Int? = nil
  ) async throws -> EventKitResponse {
    try Task.checkCancellation()
    let location = try locate()
    try location.prepareDirectory()
    try await ensureRunning(location)
    try Task.checkCancellation()
    let request = EventKitRequest(
      operation: .begin,
      resource: resource,
      listIds: listIds,
      lookaheadDays: lookaheadDays
    )
    let path = location.socketPath
    let exchange = transport
    return try await withTaskCancellationHandler {
      do {
        var response = try await exchange(request, path)
        let deadline = ContinuousClock.now.advanced(by: .seconds(300))
        while response.pending {
          try Task.checkCancellation()
          guard ContinuousClock.now < deadline else {
            throw EventKitHelperError(message: "EventKit permission or read request timed out.")
          }
          try await Task.sleep(for: .milliseconds(100))
          response = try await exchange(EventKitRequest(operation: .poll, id: request.id), path)
        }
        try Task.checkCancellation()
        if let error = response.error { throw EventKitHelperError(message: error) }
        return response
      } catch {
        // Also cancel after begin finishes, covering cancellation before the helper registered it.
        _ = try? await exchange(EventKitRequest(operation: .cancel, id: request.id), path)
        throw error
      }
    } onCancel: {
      Task {
        _ = try? await exchange(EventKitRequest(operation: .cancel, id: request.id), path)
      }
    }
  }

  private func ensureRunning(_ location: EventKitHelperLocation) async throws {
    observe(location.socketPath)
    if let response = try? await transport(EventKitRequest(operation: .ping), location.socketPath),
      response.error == nil
    {
      return
    }
    try Task.checkCancellation()
    if launch == nil {
      launch = Task {
        try await open(location.app)
        // Launch completion does not guarantee the listening socket is ready.
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
          if let response = try? await transport(
            EventKitRequest(operation: .ping),
            location.socketPath
          ),
            response.error == nil
          {
            return
          }
          try await Task.sleep(for: .milliseconds(100))
        } while ContinuousClock.now < deadline
        throw EventKitHelperError(message: "Sbar EventKit helper did not become ready.")
      }
    }
    let task = launch!
    defer { launch = nil }
    try await task.value
  }

  private func observe(_ path: String) {
    guard observedPath != path else { return }
    if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
    observedPath = path
    observer = DistributedNotificationCenter.default().addObserver(
      forName: EventKitHelperLocation.changeNotification,
      object: path,
      queue: .main
    ) { @Sendable _ in
      NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    }
  }
}
