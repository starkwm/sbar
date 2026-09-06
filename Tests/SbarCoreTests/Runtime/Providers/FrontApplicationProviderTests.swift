import AppKit
import Testing

@testable import SbarCore

@Suite("FrontApplicationProvider")
@MainActor
struct FrontApplicationProviderTests {
  @Test("application icons respect opt-in and manual refresh, including same-name switches")
  func iconRefresh() throws {
    let runtime = ProviderRuntime()
    defer { runtime.stop() }
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        """
        {"id":"app","type":"frontApplication","frontApplication":{"showIcon":true},
         "refresh":{"mode":"manual"}}
        """.utf8
      )
    )
    runtime.configure(Configuration(bar: .init(), items: .init(left: [item])))
    let first = NSImage(size: NSSize(width: 16, height: 16))
    let second = NSImage(size: NSSize(width: 16, height: 16))
    runtime.updateFrontApplication(.init(name: "App", icon: first))
    runtime.trigger("app")
    #expect(runtime.applicationIcon(for: item) === first)
    runtime.updateFrontApplication(.init(name: "App", icon: second))
    #expect(runtime.applicationIcon(for: item) === first)
    runtime.trigger("app")
    #expect(runtime.applicationIcon(for: item) === second)
    var live = item
    live.refresh = nil
    #expect(runtime.applicationIcon(for: live) === second)
    live.frontApplication = nil
    #expect(runtime.applicationIcon(for: live) == nil)
    runtime.updateFrontApplication(.init(name: "", icon: nil))
    runtime.trigger("app")
    #expect(runtime.applicationIcon(for: item) == nil)
    #expect(runtime.itemSnapshots[item.id] == "")
    runtime.stop()
    #expect(runtime.frontApplication == nil)
    #expect(runtime.applicationSnapshots.isEmpty)
  }

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
