import AppKit
import Testing

@testable import SbarCore

@Suite("FrontApplicationProvider")
@MainActor
struct FrontApplicationProviderTests {
  @Test("menu ownership publishes the initial application and subsequent changes")
  func applicationChanges() {
    let source = TestApplicationSource()
    source.application = .current
    let provider = FrontApplicationProvider(observeApplication: source.observeApplication)
    defer { provider.stop() }
    var updates: [FrontApplicationState] = []
    provider.start { updates.append($0) }

    #expect(updates.count == 1)
    #expect(updates.last?.name == NSRunningApplication.current.localizedName ?? "")

    source.application = nil

    #expect(updates.count == 2)
    #expect(updates.last?.name == "")
    #expect(updates.last?.icon == nil)

    source.application = .current

    #expect(updates.count == 3)
    #expect(updates.last?.name == NSRunningApplication.current.localizedName ?? "")
  }

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
    let source = TestApplicationSource()
    let provider = FrontApplicationProvider(observeApplication: source.observeApplication)
    defer { provider.stop() }
    var previousUpdates = 0
    var currentUpdates = 0

    provider.start { _ in previousUpdates += 1 }
    provider.start { _ in currentUpdates += 1 }
    source.application = .current

    #expect(previousUpdates == 1)
    #expect(currentUpdates == 2)
  }

  @Test("stop: removes the observer and allows a later restart")
  func restart() {
    let source = TestApplicationSource()
    let provider = FrontApplicationProvider(observeApplication: source.observeApplication)
    defer { provider.stop() }
    var updates = 0

    provider.start { _ in updates += 1 }
    provider.stop()
    source.application = .current

    #expect(updates == 1)

    provider.start { _ in updates += 1 }
    source.application = nil

    #expect(updates == 3)
  }

  @Test("deallocation removes the observation")
  func deallocationRemovesObservation() {
    let source = TestApplicationSource()
    var provider: FrontApplicationProvider? = FrontApplicationProvider(
      observeApplication: source.observeApplication
    )
    var updates = 0
    provider?.start { _ in updates += 1 }
    provider = nil
    source.application = .current

    #expect(updates == 1)
  }
}

@MainActor
private final class TestApplicationSource: NSObject {
  @objc dynamic var application: NSRunningApplication?

  func observeApplication(_ update: @escaping @MainActor (NSRunningApplication?) -> Void)
    -> NSKeyValueObservation
  {
    observe(\.application, options: [.initial, .new]) { _, change in
      let application = change.newValue ?? nil
      MainActor.assumeIsolated { update(application) }
    }
  }
}
