import Foundation
import Testing

@testable import SbarCore

@Suite("TextTemplate")
struct TextTemplateTests {
  @Test("render: substitution is literal and sections handle missing values")
  func substitution() throws {
    let template = try TextTemplate(
      "{{#artist}}{{artist}}: {{/artist}}{{title}}{{^title}}Nothing playing{{/title}}",
      fields: TextTemplate.fields(for: .media)
    )

    #expect(
      template.render(["artist": "A", "title": "<B> {{artist}} & C"]) == "A: <B> {{artist}} & C"
    )
    #expect(template.render(["title": "Track"]) == "Track")
    #expect(template.render([:]) == "Nothing playing")

    let nested = try TextTemplate("{{#a}}{{^b}}yes{{/b}}{{/a}}", fields: ["a", "b"])

    #expect(nested.render(["a": "true", "b": "false"]) == "yes")
    #expect(nested.render(["a": "false"]) == "")
    #expect(nested.render(["a": "0"]) == "yes")
  }

  @Test(
    "Configuration.validate: invalid templates fail validation",
    arguments: [
      "{{unknown}}", "{{percentage", "{{/percentage}}", "{{#available}}x",
      "{{#available}}{{/percentage}}", "{{}}",
    ]
  )
  func invalid(source: String) {
    #expect(throws: ConfigurationError.self) {
      _ = try TextTemplate(source, fields: TextTemplate.fields(for: .cpu))
    }
  }

  @Test("Configuration.init(from:): configuration round trips text and validates provider fields")
  func configuration() throws {
    let item = Item(id: "cpu", type: .cpu, text: "{{percentage}}%")
    let decoded = try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item))

    #expect(decoded == item)

    try Configuration(bar: .init(), items: .init(right: [item])).validate()
    let invalid = Item(id: "cpu", type: .cpu, text: "{{artist}}")

    #expect(throws: ConfigurationError.self) {
      try Configuration(bar: .init(), items: .init(right: [invalid])).validate()
    }
  }

  @Test(
    "Configuration.validate: layout-only items reject text",
    arguments: [ItemType.group, .divider, .spacer]
  )
  func layoutItems(type: ItemType) {
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [Item(id: "layout", type: type, text: "Hello")])
      ).validate()
    }
  }

  @Test(
    "ProviderRuntime.presentation(for:): template fields use selected media and metric settings"
  )
  func selections() {
    let cpu = WidgetState.cpu(CPUState(samples: [10, 30]))

    #expect(
      cpu.textValues(for: Item(id: "cpu", type: .cpu, cpu: .init(smoothingSamples: 2)))[
        "percentage"
      ] == "20"
    )

    let media = WidgetState.media(
      MediaState(players: [
        .music: .init(source: .music, status: .playing, title: "Music"),
        .spotify: .init(source: .spotify, status: .paused, title: "Spotify"),
      ])
    )

    #expect(
      media.textValues(for: Item(id: "media", type: .media, media: .init(source: .spotify)))[
        "title"
      ] == "Spotify"
    )
    #expect(
      WidgetState.memory(MemoryState()).textValues(for: Item(id: "ram", type: .memory)) == [
        "available": "false"
      ]
    )

    let memory = WidgetState.memory(MemoryState(usedBytes: 1024, totalBytes: 2048))

    #expect(memory.textValues(for: Item(id: "ram", type: .memory))["percentage"] == "50")
  }

  @MainActor
  @Test(
    "ProviderRuntime.presentation(for:): templates preserve snapshots, appearance, and default labels"
  )
  func runtime() {
    let item = Item(
      id: "cpu",
      type: .cpu,
      text: "Load {{percentage}}%",
      refresh: .init(mode: .manual)
    )
    let runtime = ProviderRuntime()
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    defer { runtime.stop() }
    runtime.updateWidgetState(.cpu(CPUState(samples: [10])), for: .cpu)
    runtime.trigger(item.id)
    runtime.updateWidgetState(.cpu(CPUState(samples: [90])), for: .cpu)

    #expect(runtime.presentation(for: item)?.text == "Load 10%")
    #expect(runtime.presentation(for: item)?.symbol == "cpu")
    #expect(runtime.presentation(for: item)?.accessibilityLabel == "CPU usage 10 percent")

    var changed = item
    changed.text = "{{percentage}}"
    runtime.configure(Configuration(bar: .init(), items: .init(right: [changed])))

    #expect(runtime.presentation(for: changed)?.text == "10")

    changed.text = nil

    #expect(runtime.presentation(for: changed)?.text == "CPU 10%")

    changed.text = ""

    #expect(runtime.presentation(for: changed)?.text == "")
    #expect(runtime.isVisible(changed))
  }

  @MainActor
  @Test("ProviderRuntime.presentation(for:): templates replace segments and preserve hidden state")
  func segments() {
    let runtime = ProviderRuntime()
    runtime.updateWidgetState(
      .throughput(.init(histories: ["en0": [.init(download: 1024, upload: 0)]])),
      for: .throughput
    )
    let item = Item(id: "net", type: .throughput, text: "↓{{download}} ↑{{upload}}")

    #expect(runtime.presentation(for: item)?.text == "↓1 KiB/s ↑0 B/s")
    #expect(runtime.presentation(for: item)?.segments.isEmpty == true)

    let media = Item(
      id: "media",
      type: .media,
      text: "Static",
      media: .init(hideWhenNotPlaying: true)
    )
    runtime.updateWidgetState(.media(.init()), for: .media)

    #expect(runtime.presentation(for: media)?.text == "Static")
    #expect(!runtime.isVisible(media))
  }

  @MainActor
  @Test(
    "ProviderRuntime.presentation(for:): static, application, clock, and command labels support templates"
  )
  func otherItems() {
    let runtime = ProviderRuntime()

    #expect(
      runtime.presentation(for: Item(id: "hello", type: .text, text: "Hello {{id}}"))?.text
        == "Hello hello"
    )

    runtime.updateFrontApplication(.init(name: "Terminal", icon: nil))

    #expect(
      runtime.presentation(for: Item(id: "app", type: .frontApplication, text: "App: {{name}}"))?
        .text == "App: Terminal"
    )
    #expect(
      runtime.presentation(
        for: Item(id: "clock", type: .datetime, text: "Time {{value}}", format: "'fixed'")
      )?.text == "Time fixed"
    )
    #expect(
      runtime.presentation(for: Item(id: "cmd", type: .command, text: "{{status}} {{value}}"))?.text
        == "running …"
    )
  }
}
