import Foundation

/// Owns both sides of the callback/cancellation race. EventKit does not call back after cancellation.
@MainActor
final class ReminderFetch<Value: Sendable> {
  private var continuation: CheckedContinuation<Value, any Error>?
  private var cancel: (@MainActor () -> Void)?
  private var finished = false

  func run(
    begin: (@escaping @Sendable (Value?) -> Void) -> (@MainActor () -> Void)
  ) async throws -> Value {
    try Task.checkCancellation()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        cancel = begin { value in
          Task { @MainActor in self.finish(value) }
        }
      }
    } onCancel: {
      Task { @MainActor in self.cancelRequest() }
    }
  }

  private func finish(_ value: Value?) {
    guard !finished else { return }
    finished = true
    cancel = nil
    let continuation = continuation
    self.continuation = nil
    if let value {
      continuation?.resume(returning: value)
    } else {
      continuation?.resume(throwing: RemindersReadError.unavailable)
    }
  }

  private func cancelRequest() {
    guard !finished else { return }
    finished = true
    cancel?()
    cancel = nil
    continuation?.resume(throwing: CancellationError())
    continuation = nil
  }
}
