import EventKit
import Foundation

@MainActor
final class RemindersAuthorization {
  private let status: @MainActor () -> EKAuthorizationStatus
  private let request: @MainActor () async throws -> Bool
  private var pending: Task<Bool, any Error>?

  init(
    status: @escaping @MainActor () -> EKAuthorizationStatus,
    request: @escaping @MainActor () async throws -> Bool
  ) {
    self.status = status
    self.request = request
  }

  func authorize() async throws {
    try Task.checkCancellation()
    switch status() {
    case .fullAccess, .authorized: return
    case .notDetermined:
      if pending == nil { pending = Task { try await request() } }
      let task = pending!
      defer { pending = nil }
      let granted = try await task.value
      try Task.checkCancellation()
      guard granted else { throw RemindersReadError.unauthorized }
    case .denied, .restricted: throw RemindersReadError.unauthorized
    default: throw RemindersReadError.unavailable
    }
  }
}
