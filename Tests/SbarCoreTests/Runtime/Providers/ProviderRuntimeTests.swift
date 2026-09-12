import Foundation
import Observation
import Synchronization
import Testing

@testable import SbarCore

@Suite("ProviderRuntime")
@MainActor
struct ProviderRuntimeTests {
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
