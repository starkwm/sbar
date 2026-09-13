import Testing

@testable import SbarCore

@Suite("Template state transitions")
@MainActor
struct TemplateTransitionTests {
  @Test("throughput refresh snapshots retain readings and then recover from unavailable state")
  func throughput() {
    let runtime = ProviderRuntime()
    let item = Item(
      id: "net",
      type: .throughput,
      text:
        "{{#transfers}}{{symbol}}{{number}} {{unit}}{{#separator}} | {{/separator}}{{/transfers}}{{^transfers}}{{symbol}}Offline{{/transfers}}",
      refresh: .init(mode: .manual)
    )
    runtime.configure(.init(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }
    runtime.updateWidgetState(
      .throughput(.init(histories: ["en0": [.init(download: 1024, upload: 0)]])),
      for: .throughput
    )
    runtime.trigger(item.id)
    #expect(runtime.presentation(for: item)?.text == "1 KiB/s | 0 B/s")
    runtime.updateWidgetState(.throughput(.init()), for: .throughput)
    #expect(runtime.presentation(for: item)?.text == "1 KiB/s | 0 B/s")
    runtime.trigger(item.id)
    #expect(runtime.presentation(for: item)?.text == "Offline")
    #expect(runtime.presentation(for: item)?.symbol == "questionmark")
    runtime.updateWidgetState(
      .throughput(.init(histories: ["en0": [.init(download: 0, upload: 0)]])),
      for: .throughput
    )
    runtime.trigger(item.id)
    #expect(runtime.presentation(for: item)?.text == "0 B/s | 0 B/s")
    #expect(runtime.presentation(for: item)?.symbol == nil)
    #expect(runtime.presentation(for: item)?.segments.compactMap(\.symbol).count == 2)
  }

  @Test("VPN transitions remove filtered services and aggregate icons without stale separators")
  func vpn() {
    let runtime = ProviderRuntime()
    let item = Item(
      id: "vpn",
      type: .vpn,
      text:
        "{{#connected}}{{symbol}}{{/connected}}{{#services}}{{#connected}}{{name}}{{/connected}}{{#separator}}, {{/separator}}{{/services}}{{^available}}Unavailable{{/available}}"
    )
    for active in [true, false, true] {
      runtime.updateWidgetState(
        .vpn(
          .init(
            services: [
              .init(id: "a", name: "A", status: active ? .connected : .disconnected),
              .init(id: "b", name: "B", status: .disconnected),
              .init(id: "c", name: "C", status: active ? .connected : .disconnected),
            ],
            available: true
          )
        ),
        for: .vpn
      )
      #expect(runtime.presentation(for: item)?.text == (active ? "A, C" : ""))
      #expect((runtime.presentation(for: item)?.symbol != nil) == active)
    }
    runtime.updateWidgetState(.vpn(.init(available: false)), for: .vpn)
    #expect(runtime.presentation(for: item)?.text == "Unavailable")
    #expect(runtime.presentation(for: item)?.symbol == nil)
  }
}
