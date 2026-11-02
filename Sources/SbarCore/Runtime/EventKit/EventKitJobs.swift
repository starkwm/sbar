import Foundation

/// The helper owns native requests; clients only receive value snapshots.
@MainActor
final class EventKitJobs {
  private struct Job {
    var started: Date
    var task: Task<Void, Never>?
    var result: EventKitResponse?
  }

  var isEmpty: Bool { jobs.isEmpty }

  private let read: @MainActor (EventKitRequest) async -> EventKitResponse
  private var jobs: [UUID: Job] = [:]

  init(read: @escaping @MainActor (EventKitRequest) async -> EventKitResponse) {
    self.read = read
  }

  func handle(_ request: EventKitRequest, now: Date = Date()) -> EventKitResponse {
    expire(now: now)
    switch request.operation {
    case .ping: return EventKitResponse()
    case .begin:
      guard jobs[request.id] == nil else { return EventKitResponse(pending: true) }
      guard request.resource != nil, jobs.count < 32,
        request.lookaheadDays.map({ (1...30).contains($0) }) ?? true
      else { return EventKitResponse(error: "Invalid or excessive EventKit requests.") }
      jobs[request.id] = Job(started: now)
      let task = Task { [weak self] in
        guard let self, !Task.isCancelled else { return }
        let result = await self.read(request)
        guard !Task.isCancelled, self.jobs[request.id] != nil else { return }
        self.jobs[request.id]?.result = result
        self.jobs[request.id]?.task = nil
      }
      jobs[request.id]?.task = task
      return EventKitResponse(pending: true)
    case .poll:
      guard let job = jobs[request.id] else {
        return EventKitResponse(error: "EventKit request expired or was cancelled.")
      }
      guard let result = job.result else { return EventKitResponse(pending: true) }
      jobs[request.id] = nil
      return result
    case .cancel:
      jobs.removeValue(forKey: request.id)?.task?.cancel()
      return EventKitResponse()
    }
  }

  func expire(now: Date = Date()) {
    for (id, job) in jobs where now.timeIntervalSince(job.started) >= 300 {
      jobs.removeValue(forKey: id)?.task?.cancel()
    }
  }

  func stop() {
    for job in jobs.values { job.task?.cancel() }
    jobs = [:]
  }
}
