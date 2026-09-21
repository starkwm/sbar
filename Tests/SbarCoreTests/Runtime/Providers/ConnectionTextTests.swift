import Testing

@testable import SbarCore

@MainActor
@Suite("Connection text loops")
struct ConnectionTextTests {
  @Test("VPN loops use service status, stable ordering and local default values")
  func vpn() throws {
    let runtime = ProviderRuntime()
    let state = VPNState(
      services: [
        .init(id: "z", name: "Work", status: .connecting),
        .init(id: "b", name: "Home", status: .disconnected),
        .init(id: "a", name: "Home", status: .connected),
      ],
      available: true
    )
    runtime.updateWidgetState(.vpn(state), for: .vpn)
    let item = Item(
      id: "vpn",
      type: .vpn,
      text:
        "{{status}} ({{total}}): {{#services}}{{id}}/{{serviceId}} {{#status=connected}}Secure {{name}}{{/status}}{{^status=connected}}{{value}}{{/status}}{{#separator}}, {{/separator}}{{/services}}"
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()
    let result = try #require(runtime.presentation(for: item))

    #expect(
      result.text
        == "connected (3): vpn/a Secure Home, vpn/b Home disconnected, vpn/z Work connecting"
    )
    #expect(result.accessibilityLabel == state.presentation(for: item).accessibilityLabel)
    #expect(result.symbol == "lock.shield.fill")
    #expect(result.segments.isEmpty)
  }

  @Test("Bluetooth loops expose connected devices and insert data literally")
  func bluetooth() throws {
    let runtime = ProviderRuntime()
    let state = BluetoothState(
      status: .connected,
      devices: [
        .init(id: "b", name: "Mouse"), .init(id: "a", name: " Keyboard\n{{status}} "),
      ]
    )
    runtime.updateWidgetState(.bluetooth(state), for: .bluetooth)
    let item = Item(
      id: "bt",
      type: .bluetooth,
      text:
        "{{#devices}}{{index}}/{{total}} {{deviceId}} {{name}} {{#connected}}linked{{/connected}}{{#separator}} | {{/separator}}{{/devices}}"
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()

    #expect(
      runtime.presentation(for: item)?.text
        == "1/2 a Keyboard {{status}} linked | 2/2 b Mouse linked"
    )
    #expect(
      runtime.presentation(for: item)?.accessibilityLabel
        == state.presentation(for: item).accessibilityLabel
    )
  }

  @Test("empty collections discard stale entries and preserve visibility rules")
  func empty() {
    let runtime = ProviderRuntime()
    let vpn = Item(
      id: "vpn",
      type: .vpn,
      text:
        "{{#services}}{{name}}{{#separator}}, {{/separator}}{{/services}}{{^services}}{{value}}{{/services}}",
      vpn: .init(hideWhenDisconnected: true)
    )
    runtime.updateWidgetState(
      .vpn(.init(services: [.init(id: "a", name: "Stale", status: .connected)], available: false)),
      for: .vpn
    )

    #expect(runtime.presentation(for: vpn)?.text == "VPN unavailable")
    #expect(runtime.isVisible(vpn))

    runtime.updateWidgetState(.vpn(.init(available: true)), for: .vpn)

    #expect(runtime.presentation(for: vpn)?.text == "VPN disconnected")
    #expect(!runtime.isVisible(vpn))

    let bt = Item(
      id: "bt",
      type: .bluetooth,
      text: "{{#devices}}{{value}}{{/devices}}{{^devices}}{{value}}{{/devices}}"
    )

    for status in [BluetoothStatus.off, .on, .unauthorized, .unavailable] {
      let state = BluetoothState(status: status, devices: [.init(id: "x", name: "Stale")])
      runtime.updateWidgetState(.bluetooth(state), for: .bluetooth)

      #expect(runtime.presentation(for: bt)?.text == state.text)
    }
  }

  @Test("manual snapshots retain per-service state until triggered")
  func snapshots() {
    let runtime = ProviderRuntime()
    let item = Item(
      id: "vpn",
      type: .vpn,
      text: "{{#services}}{{name}} {{status}}{{#separator}}, {{/separator}}{{/services}}",
      refresh: .init(mode: .manual)
    )
    runtime.configure(.init(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }
    runtime.updateWidgetState(
      .vpn(.init(services: [.init(id: "x", name: "Work", status: .connecting)], available: true)),
      for: .vpn
    )
    runtime.trigger(item.id)
    runtime.updateWidgetState(
      .vpn(.init(services: [.init(id: "x", name: "Work", status: .connected)], available: true)),
      for: .vpn
    )

    #expect(runtime.presentation(for: item)?.text == "Work connecting")

    runtime.trigger(item.id)

    #expect(runtime.presentation(for: item)?.text == "Work connected")
  }

  @Test(
    "collection validation rejects wrong providers, nesting and invalid states",
    arguments: [
      "{{services}}", "{{#devices}}{{name}}{{/devices}}", "{{#services=connected}}x{{/services}}",
      "{{#services}}{{#services}}{{name}}{{/services}}{{/services}}",
      "{{#services}}{{#status=conected}}x{{/status}}{{/services}}",
    ]
  )
  func invalid(text: String) {
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "vpn", type: .vpn, text: text)])
      ).validate()
    }
  }
}
