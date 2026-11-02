import Foundation
import StarkIPC
import Testing

@testable import SbarCore

@Suite("EventKitJobs")
@MainActor
struct EventKitJobsTests {
  @Test("handle: deduplicates requests, consumes results and rejects missing resources")
  func results() async throws {
    var reads = 0
    let jobs = EventKitJobs { request in
      reads += 1
      #expect(request.resource == .lists)
      return EventKitResponse(lists: [])
    }
    let request = EventKitRequest(operation: .begin, resource: .lists)

    #expect(jobs.handle(request).pending)
    #expect(jobs.handle(request).pending)
    try await waitUntil { reads == 1 }
    #expect(jobs.handle(EventKitRequest(operation: .poll, id: request.id)).lists == [])
    #expect(jobs.isEmpty)
    #expect(jobs.handle(EventKitRequest(operation: .poll, id: request.id)).error != nil)
    #expect(jobs.handle(EventKitRequest(operation: .begin)).error != nil)
  }

  @Test("handle: cancellation and expiration discard late native results")
  func cancellation() async throws {
    var continuations: [CheckedContinuation<EventKitResponse, Never>] = []
    let jobs = EventKitJobs { _ in
      await withCheckedContinuation { continuations.append($0) }
    }
    let first = EventKitRequest(operation: .begin, resource: .reminders)
    let second = EventKitRequest(operation: .begin, resource: .calendar)
    let now = Date()
    _ = jobs.handle(first, now: now)
    _ = jobs.handle(second, now: now)
    try await waitUntil { continuations.count == 2 }
    _ = jobs.handle(EventKitRequest(operation: .cancel, id: first.id), now: now)
    jobs.expire(now: now.addingTimeInterval(300))
    #expect(jobs.isEmpty)

    for continuation in continuations {
      continuation.resume(returning: EventKitResponse(lists: []))
    }
    await Task.yield()
    #expect(jobs.handle(EventKitRequest(operation: .poll, id: first.id)).error != nil)
    #expect(jobs.handle(EventKitRequest(operation: .poll, id: second.id)).error != nil)
  }

  @Test("stop: cancels pending tasks and drops their results")
  func stop() async throws {
    var started = false
    var cancelled = false
    let jobs = EventKitJobs { _ in
      started = true
      do { try await Task.sleep(for: .seconds(60)) } catch { cancelled = true }
      return EventKitResponse(lists: [])
    }
    _ = jobs.handle(EventKitRequest(operation: .begin, resource: .lists))
    try await waitUntil { started }
    jobs.stop()
    try await waitUntil { cancelled }
    #expect(jobs.isEmpty)
  }
}

@Suite("EventKitClient")
@MainActor
struct EventKitClientTests {
  @Test("request: launches once, probes readiness and returns helper data for concurrent clients")
  func launch() async throws {
    let fixture = HelperFixture()
    let client = fixture.client()
    async let first = client.request(.lists)
    async let second = client.request(.lists)
    let results = try await [first, second]

    #expect(results.allSatisfy { $0.lists == [] })
    #expect(fixture.launches == 1)
    #expect(fixture.pings >= 3)
    #expect(fixture.jobs.isEmpty)

    fixture.running = false
    let afterExit = try await client.request(.lists)
    #expect(afterExit.lists == [])
    #expect(fixture.launches == 2)
  }

  @Test("request: cancellation reaches the helper without publishing a late result")
  func cancel() async throws {
    let fixture = HelperFixture(suspended: true)
    let client = fixture.client()
    let task = Task { try await client.request(.reminders) }
    try await waitUntil { !fixture.jobs.isEmpty }
    task.cancel()
    do {
      _ = try await task.value
      Issue.record("Expected cancellation")
    } catch { #expect(error is CancellationError) }
    try await waitUntil { fixture.jobs.isEmpty }
  }

  @Test("request: missing packaging and helper errors remain actionable failures")
  func errors() async {
    let client = EventKitClient(
      locate: {
        throw EventKitHelperError(message: "Helper missing")
      },
      open: { _ in Issue.record("Must not launch without a helper") }
    )
    do {
      _ = try await client.request(.lists)
      Issue.record("Expected failure")
    } catch { #expect(error.localizedDescription == "Helper missing") }
  }

  @Test("exchange: transfers date components and calendar states through the real socket protocol")
  func transport() async throws {
    let path = "/tmp/sbar-eventkit-test-\(UUID().uuidString).sock"
    let due = DateComponents(
      timeZone: TimeZone(identifier: "Europe/London"),
      year: 2026,
      month: 11,
      day: 2,
      hour: 14
    )
    let reminders = RemindersState(
      access: .empty,
      reminders: [ReminderRecord(id: "r", listId: "l", title: "Task", due: due)]
    )
    let calendar = CalendarState(
      access: .empty,
      events: [
        CalendarEvent(
          title: "Meeting",
          calendar: "Work",
          start: Date(),
          end: Date().addingTimeInterval(60),
          allDay: false
        )
      ]
    )
    let server = SocketServer<EventKitRequest, EventKitResponse>(
      path: path,
      errorResponse: { EventKitResponse(error: $0.localizedDescription) },
      handler: { request in
        #expect(request.resource == .reminders)
        return SocketReply(EventKitResponse(reminders: reminders, calendar: calendar))
      }
    )
    try server.start()
    defer {
      server.stop()
      try? FileManager.default.removeItem(atPath: path + ".lock")
    }
    let result = try await EventKitClient.exchange(
      EventKitRequest(operation: .begin, resource: .reminders),
      path: path
    )

    #expect(result.reminders == reminders)
    #expect(result.calendar == calendar)
  }
}

@MainActor
private final class HelperFixture {
  var launches = 0
  var pings = 0
  var running = false
  var readinessChecks = 0
  let jobs: EventKitJobs

  init(suspended: Bool = false) {
    jobs = EventKitJobs { _ in
      if suspended { try? await Task.sleep(for: .seconds(60)) }
      return EventKitResponse(lists: [])
    }
  }

  func client() -> EventKitClient {
    EventKitClient(
      locate: {
        EventKitHelperLocation(app: URL(fileURLWithPath: "/tmp/test-helper.app"), build: "fixture")
      },
      transport: { request, _ in try await self.handle(request) },
      open: { _ in
        self.launches += 1
        try await Task.sleep(for: .milliseconds(20))
        self.readinessChecks = 0
        self.running = true
      }
    )
  }

  private func handle(_ request: EventKitRequest) throws -> EventKitResponse {
    if request.operation == .ping { pings += 1 }
    guard running else { throw EventKitHelperError(message: "Not running") }
    if request.operation == .ping {
      readinessChecks += 1
      if readinessChecks == 1 { throw EventKitHelperError(message: "Socket not yet ready") }
    }
    return jobs.handle(request)
  }
}

@Suite("EventKitHelperLocation")
struct EventKitHelperLocationTests {
  @Test("socketPath: build and install identities produce distinct bounded socket paths")
  func identity() {
    let first = EventKitHelperLocation(
      app: URL(fileURLWithPath: "/one/Sbar EventKit.app"),
      build: "one"
    )
    let second = EventKitHelperLocation(app: first.app, build: "two")
    let third = EventKitHelperLocation(
      app: URL(fileURLWithPath: "/other/Sbar EventKit.app"),
      build: "one"
    )

    #expect(first.socketPath != second.socketPath)
    #expect(first.socketPath != third.socketPath)
    #expect(first.socketPath.utf8.count < 104)
  }

  @Test("resolve: a standalone executable without its helper gives installation guidance")
  func missing() {
    #expect(throws: EventKitHelperError.self) {
      try EventKitHelperLocation.resolve(executable: URL(fileURLWithPath: "/missing/sbar"))
    }
  }
}
