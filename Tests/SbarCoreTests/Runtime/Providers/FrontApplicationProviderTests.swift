import AppKit
import Testing

@testable import SbarCore

@Suite("FrontApplicationProvider")
@MainActor
struct FrontApplicationProviderTests {
  @Test("start: replaces the previous observer when restarted")
  func startReplacesPreviousObserver() {
    let provider = FrontApplicationProvider()
    defer { provider.stop() }
    var previousUpdates = 0
    var currentUpdates = 0

    provider.start { _ in previousUpdates += 1 }
    provider.start { _ in currentUpdates += 1 }
    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    #expect(previousUpdates == 1)
    #expect(currentUpdates == 2)
  }

  @Test("stop: removes the observer and allows a later restart")
  func stopRemovesObserverAndAllowsRestart() {
    let provider = FrontApplicationProvider()
    defer { provider.stop() }
    var updates = 0

    provider.start { _ in updates += 1 }
    provider.stop()
    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    #expect(updates == 1)

    provider.start { _ in updates += 1 }
    NSWorkspace.shared.notificationCenter.post(
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    #expect(updates == 3)
  }
}
