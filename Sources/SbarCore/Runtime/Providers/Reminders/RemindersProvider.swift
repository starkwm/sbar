import AppKit
import EventKit
import Foundation

@MainActor
final class RemindersProvider {
  private(set) var listIds: Set<String>?

  private let read: @MainActor (Set<String>?, Date) async -> RemindersState
  private let clock: @MainActor () -> Date
  private var update: (@MainActor (RemindersState) -> Void)?
  private var generation = 0
  private var reading: Task<Void, Never>?
  private var poll: Task<Void, Never>?
  private var transition: Task<Void, Never>?
  private var pending = false
  private var state = RemindersState()
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []

  init(
    read: (@MainActor (Set<String>?, Date) async -> RemindersState)? = nil,
    clock: @escaping @MainActor () -> Date = { Date() }
  ) {
    let store = SystemRemindersStore()
    self.read = read ?? { ids, now in await store.read(listIds: ids, now: now) }
    self.clock = clock
  }

  func start(listIds: Set<String>?, update: @escaping @MainActor (RemindersState) -> Void) {
    stop()
    self.listIds = listIds
    self.update = update
    state = RemindersState(now: clock())
    update(state)
    let generation = generation
    for (center, name) in [
      (NotificationCenter.default, Notification.Name.EKEventStoreChanged),
      (NotificationCenter.default, Notification.Name.NSSystemTimeZoneDidChange),
      (NotificationCenter.default, Notification.Name.NSSystemClockDidChange),
      (NotificationCenter.default, Notification.Name.NSCalendarDayChanged),
      (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
    ] {
      let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in
          guard let self, self.generation == generation else { return }
          self.reclassify()
          self.reload()
        }
      }
      observers.append((center, observer))
    }
    reload()
    poll = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(60)) } catch { return }
        guard let self, self.generation == generation else { return }
        self.reclassify()
        self.reload()
      }
    }
  }

  func stop() {
    generation += 1
    reading?.cancel()
    poll?.cancel()
    transition?.cancel()
    reading = nil
    poll = nil
    transition = nil
    pending = false
    update = nil
    state = RemindersState()
    for (center, observer) in observers { center.removeObserver(observer) }
    observers = []
  }

  func reload() {
    guard update != nil else { return }
    guard reading == nil else {
      pending = true
      return
    }
    let generation = generation
    let ids = listIds
    reading = Task { [weak self] in
      guard let self, !Task.isCancelled, self.generation == generation else { return }
      let result = await self.read(ids, self.clock())
      guard !Task.isCancelled, self.generation == generation else { return }
      self.state = result
      self.reading = nil
      self.reclassify()
      if self.pending {
        self.pending = false
        self.reload()
      }
    }
  }

  private func reclassify() {
    guard let update else { return }
    state.now = clock()
    state.timeZone = .current
    update(state)
    transition?.cancel()
    guard let next = state.nextTransition() else { return }
    let generation = generation
    let delay = max(0.001, next.timeIntervalSince(state.now))
    transition = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      guard let self, self.generation == generation else { return }
      self.reclassify()
    }
  }
}
