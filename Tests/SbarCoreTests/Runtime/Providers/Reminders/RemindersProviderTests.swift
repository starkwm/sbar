import EventKit
import Foundation
import Synchronization
import Testing

@testable import SbarCore

@Suite("RemindersProvider")
@MainActor
struct RemindersProviderTests {
  @Test("start: shares reads, coalesces changes and rejects callbacks after restart")
  func lifecycle() async throws {
    var reads: [Set<String>?] = []
    var continuations: [CheckedContinuation<RemindersState, Never>] = []
    let provider = RemindersProvider { ids, _ in
      reads.append(ids)
      return await withCheckedContinuation { continuations.append($0) }
    }
    defer { provider.stop() }
    var updates: [RemindersState] = []
    provider.start(listIds: ["a"]) { updates.append($0) }
    try await waitUntil { continuations.count == 1 }
    provider.reload()
    provider.reload()
    continuations[0].resume(returning: RemindersState(access: .empty))
    try await waitUntil { continuations.count == 2 }
    #expect(reads.count == 2)

    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    provider.start(listIds: ["b"]) { updates.append($0) }
    try await waitUntil { continuations.count == 3 }
    let before = updates.count
    continuations[1].resume(returning: RemindersState(access: .unauthorized))
    continuations[2].resume(returning: RemindersState(access: .empty))
    try await waitUntil { updates.count > before }
    #expect(updates.last?.access == .empty)
    #expect(!updates.contains { $0.access == .unauthorized })
    #expect(reads == [["a"], ["a"], ["b"]])

    provider.stop()
    let count = reads.count
    NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
    try await Task.sleep(for: .milliseconds(30))
    #expect(reads.count == count)
  }

  @Test("stop: a suspended read cannot publish after stopping")
  func stopDuringRead() async throws {
    var continuation: CheckedContinuation<RemindersState, Never>?
    let provider = RemindersProvider { _, _ in
      await withCheckedContinuation { continuation = $0 }
    }
    var updates = 0
    provider.start(listIds: nil) { _ in updates += 1 }
    try await waitUntil { continuation != nil }
    provider.stop()
    continuation?.resume(returning: RemindersState(access: .empty))
    try await Task.sleep(for: .milliseconds(30))

    #expect(updates == 1)
  }
}

@Suite("ReminderFetch")
@MainActor
struct ReminderFetchTests {
  @Test("run: cancellation resumes the waiter and ignores late or duplicate callbacks")
  func cancellation() async throws {
    var callback: (@Sendable ([Int]?) -> Void)?
    var cancellations = 0
    let fetch = ReminderFetch<[Int]>()
    let task = Task {
      try await fetch.run { completion in
        callback = completion
        return { cancellations += 1 }
      }
    }
    try await waitUntil { callback != nil }
    task.cancel()
    do {
      _ = try await task.value
      Issue.record("Expected cancellation")
    } catch { #expect(error is CancellationError) }
    callback?([1])
    callback?([2])
    try await Task.sleep(for: .milliseconds(20))

    #expect(cancellations == 1)
  }

  @Test("run: synchronous completion and nil failure resolve once")
  func completion() async throws {
    let value = try await ReminderFetch<[Int]>().run { completion in
      completion([1])
      completion([2])
      return {}
    }
    #expect(value == [1])
    do {
      _ = try await ReminderFetch<[Int]>().run { completion in
        completion(nil)
        return {}
      }
      Issue.record("Expected failure")
    } catch { #expect(error is RemindersReadError) }
  }

  @Test("run: an already cancelled task never starts native fetching")
  func alreadyCancelled() async {
    var began = false
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await ReminderFetch<[Int]>().run { _ in
        began = true
        return {}
      }
    }
    _ = await task.result
    #expect(!began)
  }
}

@Suite("RemindersAuthorization")
@MainActor
struct RemindersAuthorizationTests {
  @Test("authorize: denial does not prompt again and later grants are recognized")
  func permissions() async throws {
    let status = Mutex(EKAuthorizationStatus.denied)
    var requests = 0
    let auth = RemindersAuthorization(
      status: { status.withLock { $0 } },
      request: {
        requests += 1
        return true
      }
    )
    for value in [EKAuthorizationStatus.denied, .restricted] {
      status.withLock { $0 = value }
      do {
        try await auth.authorize()
        Issue.record("Expected denial")
      } catch { #expect(error as? RemindersReadError == .unauthorized) }
    }
    #expect(requests == 0)
    status.withLock { $0 = .fullAccess }
    try await auth.authorize()
    #expect(requests == 0)
    status.withLock { $0 = .notDetermined }
    try await auth.authorize()
    #expect(requests == 1)
  }

  @Test("authorize: concurrent activations share one prompt and a cancelled waiter does not fetch")
  func concurrentPermission() async throws {
    var continuation: CheckedContinuation<Bool, Never>?
    var requests = 0
    let auth = RemindersAuthorization(
      status: { .notDetermined },
      request: {
        requests += 1
        return await withCheckedContinuation { continuation = $0 }
      }
    )
    let first = Task { try await auth.authorize() }
    try await waitUntil { continuation != nil }
    let second = Task { try await auth.authorize() }
    await Task.yield()
    first.cancel()
    continuation?.resume(returning: true)
    _ = try await second.value
    do {
      try await first.value
      Issue.record("Expected cancellation")
    } catch { #expect(error is CancellationError) }
    #expect(requests == 1)
  }
}
