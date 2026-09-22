import Foundation
import Testing

@testable import SbarCore

@Suite("TextTemplate")
struct TextTemplateConditionTests {
  @Test(
    "allowedValues(for:): every declared status is accepted by its provider",
    arguments: [
      ItemType.battery, .volume, .network, .vpn, .bluetooth, .audioDevice, .media, .mail, .command,
      .plugin,
    ]
  )
  func statusVocabulary(type: ItemType) throws {
    let allowed = TextTemplate.allowedValues(for: type)

    for status in try #require(allowed["status"]) {
      let template = try TextTemplate(
        "{{#status=\(status)}}yes{{/status}}",
        fields: TextTemplate.fields(for: type),
        allowedValues: allowed
      )

      #expect(template.render(["status": status]) == "yes")
    }
  }

  @Test("render: equality, inverse, nested same-field sections, and fallback labels")
  func conditions() throws {
    let template = try TextTemplate(
      "{{#status=connected}}Secure{{/status}}{{^status=connected}}{{#status=connecting}}Wait{{/status}}{{^status=connecting}}{{value}}{{/status}}{{/status}}",
      fields: TextTemplate.fields(for: .vpn),
      allowedValues: TextTemplate.allowedValues(for: .vpn)
    )

    #expect(template.render(["status": "connected", "value": "VPN connected"]) == "Secure")
    #expect(template.render(["status": "connecting"]) == "Wait")
    #expect(
      template.render(["status": "disconnected", "value": "VPN disconnected"]) == "VPN disconnected"
    )
    #expect(template.render(["value": "Waiting"]) == "Waiting")

    let literal = try TextTemplate("{{# title = A song }}{{title}}{{/title}}", fields: ["title"])

    #expect(literal.render(["title": "A song"]) == "A song")
    #expect(literal.render(["title": "a song"]) == "")
  }

  @Test(
    "Configuration.validate: invalid equality expressions and states fail item validation",
    arguments: [
      "{{#status=conected}}x{{/status}}", "{{^status=unknown}}x{{/status}}",
      "{{#status=}}x{{/status}}", "{{status=connected}}", "{{#missing=x}}x{{/missing}}",
      "{{#status=connected}}x{{/status=connected}}", "{{#connected=yes}}x{{/connected}}",
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

  @Test("WidgetState.textValues(for:): battery and volume statuses use explicit precedence")
  func statuses() {
    let battery = Item(id: "battery", type: .battery)

    for (state, status) in [
      (WidgetState.battery(percentage: nil, charging: false, pluggedIn: true), "noBattery"),
      (.battery(percentage: 40, charging: true, pluggedIn: true), "charging"),
      (.battery(percentage: 100, charging: false, pluggedIn: true), "pluggedIn"),
      (.battery(percentage: 40, charging: false, pluggedIn: false), "onBattery"),
    ] { #expect(state.textValues(for: battery)["status"] == status) }

    let volume = Item(id: "volume", type: .volume)

    for (state, status) in [
      (WidgetState.volume(percentage: 40, muted: true, available: false), "unavailable"),
      (.volume(percentage: nil, muted: true, available: true), "muted"),
      (.volume(percentage: nil, muted: false, available: true), "fixed"),
      (.volume(percentage: 0, muted: false, available: true), "available"),
    ] { #expect(state.textValues(for: volume)["status"] == status) }
  }

  @MainActor
  @Test(
    "ProviderRuntime.presentation(for:): state templates preserve filtered states, audio selection and native accessibility"
  )
  func presentation() throws {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(.network(.ethernet), for: .network)
    let wifi = Item(
      id: "wifi",
      type: .network,
      text: "{{#status=offline}}No Wi-Fi{{/status}}{{^status=offline}}{{value}}{{/status}}",
      network: .init(interface: .wifi, hideWhenDisconnected: true)
    )
    let connection = try #require(runtime.presentation(for: wifi))

    #expect(connection.text == "No Wi-Fi")
    #expect(connection.hidden)
    #expect(connection.accessibilityLabel == "Wi-Fi disconnected")

    runtime.updateWidgetState(
      .audioDevice(
        .init(
          output: .init(status: .available, name: "Speakers"),
          input: .init(status: .disconnected)
        )
      ),
      for: .audioDevice
    )
    let mic = Item(
      id: "mic",
      type: .audioDevice,
      text:
        "{{#status=disconnected}}No microphone{{/status}}{{^status=disconnected}}{{value}}{{/status}}",
      audioDevice: .init(device: .input)
    )

    #expect(runtime.presentation(for: mic)?.text == "No microphone")
    #expect(runtime.presentation(for: mic)?.accessibilityLabel == "No input")
  }
}
