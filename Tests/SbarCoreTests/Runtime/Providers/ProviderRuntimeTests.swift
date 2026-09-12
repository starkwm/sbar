import Foundation
import Observation
import Synchronization
import Testing

@testable import SbarCore

@Suite("ProviderRuntime")
@MainActor
struct ProviderRuntimeTests {
  @Test("refresh edits preserve other items and discard removed snapshots")
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

  @Test("disk path edits only replace the affected disk snapshot")
  func independentDiskPaths() {
    let first = Item(
      id: "first",
      type: .disk,
      disk: DiskConfiguration(path: "/a", format: .percentage),
      refresh: .init(mode: .manual)
    )
    let second = Item(
      id: "second",
      type: .disk,
      disk: DiskConfiguration(path: "/b", format: .percentage),
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

  @Test("adding and removing another provider preserves active playback and metric state")
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

  @Test("unchanged shared values do not invalidate observation")
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

  @Test("unchanged command and plugin values do not invalidate observation")
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

  @Test("batched shared updates emit events only for changed values")
  func changedValueEvents() {
    let runtime = ProviderRuntime()
    runtime.updateSharedValues([.cpu: "10%", .memory: "50%"])
    var events: [String: String] = [:]
    runtime.onValueChange = { events[$0] = $1 }

    runtime.updateSharedValues([.cpu: "11%", .memory: "50%"])
    #expect(events == ["cpu": "11%"])
  }
}
