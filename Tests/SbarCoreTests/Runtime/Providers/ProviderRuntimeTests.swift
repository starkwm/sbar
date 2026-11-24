import AppKit
import Observation
import Synchronization
import Testing

@testable import SbarCore

@Suite("ProviderRuntime")
@MainActor
struct ProviderRuntimeTests {
  @Test("startObservingSpaces: panel and widget share updates across widget removal and addition")
  func sharedSpaces() async throws {
    let workspace = NotificationCenter()
    var current = SpacesState(
      displays: [
        SpaceDisplay(identifier: "a", spaces: [SpaceEntry(id: 1)], activeID: 1),
        SpaceDisplay(
          identifier: "b",
          spaces: [SpaceEntry(id: 2), SpaceEntry(id: 3, fullscreen: true)],
          activeID: 2
        ),
      ],
      focusedID: 1
    )
    var reads = 0
    let runtime = ProviderRuntime(
      spaces: SpacesProvider(
        query: {
          reads += 1
          return current
        },
        workspace: workspace,
        application: NotificationCenter()
      )
    )
    defer { runtime.stop() }
    let item = Item(id: "spaces", type: .spaces, spaces: .init(scope: .display))
    let withWidget = Configuration(bar: .init(), items: .init(right: [item]))
    let withoutWidget = Configuration(bar: .init(), items: .init())
    var panelStates: [SpacesState?] = []
    runtime.startObservingSpaces { panelStates.append(runtime.spacesState) }
    runtime.configure(withoutWidget)

    #expect(panelStates == [current])
    #expect(runtime.sharedValues[.spaces] == nil)

    runtime.configure(withWidget)

    #expect(runtime.widgetStates[.spaces] == .spaces(current))
    #expect(runtime.presentation(for: item, displayUUID: "B")?.text == "1")
    #expect(reads == 1)

    current.displays[1].activeID = 3
    workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    try await waitUntil { panelStates.count == 2 }

    #expect(runtime.spacesState?.isFullscreen(displayUUID: "B") == true)
    #expect(runtime.spacesState?.isFullscreen(displayUUID: "A") == false)
    #expect(panelStates.last == current)
    #expect(runtime.widgetStates[.spaces] == .spaces(current))
    #expect(runtime.presentation(for: item, displayUUID: "B")?.text == "2")

    runtime.configure(withoutWidget)
    current.displays[1].activeID = 2
    workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    try await waitUntil { panelStates.count == 3 }

    #expect(panelStates.last == current)
    #expect(runtime.widgetStates[.spaces] == nil)
    #expect(runtime.sharedValues[.spaces] == nil)

    runtime.configure(withWidget)

    #expect(runtime.widgetStates[.spaces] == .spaces(current))
    #expect(reads == 3)
  }

  @Test("startObservingSpaces: restart publishes the initial snapshot and retries incomplete data")
  func restartSpaceObservation() async throws {
    let workspace = NotificationCenter()
    let complete = SpacesState(
      displays: [SpaceDisplay(identifier: "main", spaces: [SpaceEntry(id: 1)], activeID: 1)],
      focusedID: 1
    )
    var current = complete
    var reads = 0
    let runtime = ProviderRuntime(
      spaces: SpacesProvider(
        query: {
          reads += 1
          return current
        },
        workspace: workspace,
        application: NotificationCenter()
      )
    )
    defer { runtime.stop() }
    let item = Item(id: "spaces", type: .spaces)
    let configuration = Configuration(bar: .init(), items: .init(right: [item]))
    var firstUpdates = 0
    runtime.startObservingSpaces {
      firstUpdates += 1
      runtime.configure(configuration)
    }
    runtime.startObservingSpaces { Issue.record("Repeated start replaced the panel callback") }

    #expect(runtime.widgetStates[.spaces] == .spaces(complete))
    workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    runtime.stop()
    workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

    #expect(runtime.spacesState == nil)
    #expect(runtime.widgetStates[.spaces] == nil)

    current = SpacesState()
    var updates = 0
    runtime.startObservingSpaces {
      updates += 1
      runtime.configure(configuration)
    }

    #expect(updates == 1)
    #expect(runtime.spacesState == current)
    #expect(runtime.presentation(for: item)?.text == "Spaces unavailable")

    current = complete
    try await waitUntil { updates == 2 }

    #expect(runtime.spacesState == complete)
    #expect(runtime.widgetStates[.spaces] == .spaces(complete))
    #expect(firstUpdates == 1)
    #expect(reads == 3)
  }

  @Test("configure: refresh edits preserve other items and discard removed snapshots")
  func independentRefreshSnapshots() {
    let manual = Item(id: "manual", type: .cpu, refresh: .init(mode: .manual))
    let clock = Item(id: "clock", type: .datetime, refresh: .init(mode: .manual))
    var configuration = Configuration(
      bar: .init(),
      items: .init(right: [
        manual, clock, Item(id: "other", type: .cpu, refresh: .init(mode: .event)),
      ])
    )
    let runtime = ProviderRuntime()
    runtime.configure(configuration)
    defer { runtime.stop() }
    runtime.updateWidgetState(.cpu(CPUState(samples: [10])), for: .cpu)
    runtime.trigger(manual.id)
    let date = runtime.itemDates[clock.id]
    runtime.updateWidgetState(.cpu(CPUState(samples: [90])), for: .cpu)

    configuration.items.right[2].refresh = .init(mode: .interval, seconds: 60)
    runtime.configure(configuration)

    #expect(runtime.presentation(for: manual)?.text == "CPU 10%")
    #expect(runtime.itemSnapshots[manual.id] == "CPU 10%")
    #expect(runtime.itemDates[clock.id] == date)
    #expect(runtime.presentation(for: configuration.items.right[2])?.text == "CPU 90%")

    configuration.items.right.removeLast()
    runtime.configure(configuration)

    #expect(runtime.presentation(for: manual)?.text == "CPU 10%")
    #expect(runtime.itemDates[clock.id] == date)
    #expect(runtime.itemSnapshots["other"] == nil)
    #expect(runtime.widgetSnapshots["other"] == nil)

    configuration.items.right[0].refresh = nil
    runtime.configure(configuration)

    #expect(runtime.presentation(for: configuration.items.right[0])?.text == "CPU 90%")
    #expect(runtime.itemSnapshots[manual.id] == nil)
    #expect(runtime.widgetSnapshots[manual.id] == nil)
  }

  @Test("configure: re-added items capture fresh data, not the stopped provider's last state")
  func reactivatedItemsCaptureFreshState() async throws {
    var unread = 1
    let mail = MailProvider(interval: .seconds(60)) {
      MailState(status: .available, unreadCount: unread)
    }
    let runtime = ProviderRuntime(mail: mail)
    defer { runtime.stop() }
    let manual = Item(id: "manual", type: .mail, refresh: .init(mode: .manual))
    let interval = Item(id: "interval", type: .mail, refresh: .init(mode: .interval, seconds: 60))
    let configuration = Configuration(bar: .init(), items: .init(right: [manual, interval]))
    runtime.configure(configuration)
    try await waitUntil { runtime.presentation(for: manual)?.text == "1 unread" }

    runtime.configure(Configuration(bar: .init(), items: .init()))
    unread = 9
    runtime.configure(configuration)

    #expect(runtime.presentation(for: manual)?.text != "1 unread")

    try await waitUntil { runtime.sharedValues[.mail] == "9 unread" }

    let fresh = WidgetState.mail(MailState(status: .available, unreadCount: 9))

    for item in [manual, interval] {
      #expect(runtime.presentation(for: item)?.text == "9 unread")
      #expect(runtime.widgetSnapshots[item.id] == fresh)
    }
  }

  @Test("configure: disk path edits only replace the affected disk snapshot")
  func independentDiskPaths() {
    let first = Item(
      id: "first",
      type: .disk,
      text: "{{percentage}}% used",
      disk: DiskConfiguration(path: "/a"),
      refresh: .init(mode: .manual)
    )
    let second = Item(
      id: "second",
      type: .disk,
      text: "{{percentage}}% used",
      disk: DiskConfiguration(path: "/b"),
      refresh: .init(mode: .manual)
    )
    var configuration = Configuration(bar: .init(), items: .init(right: [first, second]))
    let runtime = ProviderRuntime()
    runtime.configure(configuration)
    defer { runtime.stop() }
    runtime.updateDiskStates([
      "/a": DiskState(freeBytes: 90, totalBytes: 100),
      "/b": DiskState(freeBytes: 50, totalBytes: 100),
    ])
    runtime.trigger(first.id)
    runtime.trigger(second.id)
    runtime.updateDiskStates([
      "/a": DiskState(freeBytes: 10, totalBytes: 100),
      "/b": DiskState(freeBytes: 20, totalBytes: 100),
    ])

    configuration.items.right[1].disk?.path = "/c"
    runtime.configure(configuration)

    #expect(runtime.presentation(for: first)?.text == "10% used")
    #expect(runtime.presentation(for: configuration.items.right[1])?.symbol == "questionmark")
    #expect(runtime.diskStates["/b"] == nil)
  }

  @Test(
    "configure: adding and removing another provider preserves active playback and metric state"
  )
  func unrelatedProviderChanges() {
    let media = Item(id: "media", type: .media)
    let cpu = Item(id: "cpu", type: .cpu)
    var configuration = Configuration(bar: .init(), items: .init(right: [media, cpu]))
    let runtime = ProviderRuntime()
    runtime.configure(configuration)
    defer { runtime.stop() }
    runtime.updateWidgetState(
      .media(
        MediaState(players: [
          .music: MediaPlayerState(source: .music, status: .playing, title: "Playing track")
        ])
      ),
      for: .media
    )
    runtime.updateWidgetState(.cpu(CPUState(samples: [10, 20])), for: .cpu)

    configuration.items.right.append(Item(id: "clock", type: .datetime))
    runtime.configure(configuration)

    #expect(runtime.presentation(for: media)?.text == "Playing track")
    #expect(runtime.widgetStates[.cpu] == .cpu(CPUState(samples: [10, 20])))

    configuration.items.right.removeLast()
    runtime.configure(configuration)

    #expect(runtime.presentation(for: media)?.text == "Playing track")
    #expect(runtime.widgetStates[.cpu] == .cpu(CPUState(samples: [10, 20])))

    runtime.stop()
    runtime.configure(configuration)

    #expect(runtime.presentation(for: media)?.text == "Waiting for playback")
    #expect(runtime.widgetStates[.cpu] == .cpu(CPUState()))
  }

  @Test("updateSharedValues: unchanged shared values do not invalidate observation")
  func unchangedSharedValues() {
    let runtime = ProviderRuntime()
    runtime.updateSharedValues([.cpu: "10%", .memory: "50%"])
    let changes = Mutex(0)
    withObservationTracking {
      _ = runtime.sharedValues
    } onChange: {
      changes.withLock { $0 += 1 }
    }

    runtime.updateSharedValues([.cpu: "10%"])
    runtime.updateSharedValues([.cpu: "10%", .memory: "50%"])

    #expect(changes.withLock { $0 } == 0)

    runtime.updateSharedValues([.cpu: "11%"])

    #expect(changes.withLock { $0 } == 1)
    #expect(runtime.sharedValues[.memory] == "50%")
  }

  @Test("updateSharedValues: batched shared updates emit events only for changed values")
  func changedValueEvents() {
    let runtime = ProviderRuntime()
    runtime.updateSharedValues([.cpu: "10%", .memory: "50%"])
    var events: [String: String] = [:]
    runtime.onValueChange = { events[$0] = $1 }

    runtime.updateSharedValues([.cpu: "11%", .memory: "50%"])

    #expect(events == ["cpu": "11%"])
  }

  @Test("updateItemValue: unchanged command and plugin values do not invalidate observation")
  func unchangedItemValues() {
    let runtime = ProviderRuntime()
    runtime.updateItemValue("Ready", for: "status")
    let changes = Mutex(0)
    withObservationTracking {
      _ = runtime.itemValues
    } onChange: {
      changes.withLock { $0 += 1 }
    }

    runtime.updateItemValue("Ready", for: "status")

    #expect(changes.withLock { $0 } == 0)

    runtime.updateItemValue("Busy", for: "status")

    #expect(changes.withLock { $0 } == 1)
    #expect(runtime.itemValues["status"] == "Busy")
  }
}
