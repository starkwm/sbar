import Foundation
import Observation
import Synchronization
import Testing

@testable import SbarCore

@Suite("ProviderRuntime")
@MainActor
struct ProviderRuntimeTests {
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
