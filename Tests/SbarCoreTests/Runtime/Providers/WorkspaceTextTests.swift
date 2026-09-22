import Testing

@testable import SbarCore

@Suite("ProviderRuntime")
struct WorkspaceTextTests {
  @Test("presentation(for:): separators retain inactive styling as the active workspace changes")
  func separators() {
    let item = Item(
      id: "spaces",
      type: .spaces,
      text:
        "{{#workspaces}}{{name}}{{#separator}}{{#available}} · {{/available}}{{/separator}}{{/workspaces}}",
      spaces: .init(tints: .init(active: "#FFFFFF", inactive: "#888888"))
    )

    for active in [UInt64(1), 2, 3] {
      let state = SpacesState(
        displays: [
          .init(
            identifier: "main",
            spaces: [.init(id: 1), .init(id: 2), .init(id: 3)],
            activeID: active
          )
        ],
        focusedID: active
      )
      let result = state.presentation(for: item)

      #expect(result.text == "1 · 2 · 3")
      #expect(result.segments.count == 5)

      for index in [1, 3] {
        #expect(result.segments[index].text == " · ")
        #expect(result.segments[index].tint == "#888888")
        #expect(!result.segments[index].emphasized)
      }

      #expect(result.segments[(Int(active) - 1) * 2].emphasized)
    }

    let single = SpacesState(
      displays: [.init(identifier: "main", spaces: [.init(id: 1)], activeID: 1)],
      focusedID: 1
    )

    #expect(single.presentation(for: item).text == "1")
    #expect(SpacesState().presentation(for: item).text.isEmpty)
  }

  @Test("presentation(for:): loops preserve entry identity, separators and conditions")
  func loops() throws {
    let template = try TextTemplate(
      "[{{#workspaces}}{{#active}}*{{/active}}{{name}}{{^last}}, {{/last}}{{/workspaces}}]",
      fields: TextTemplate.fields(for: .spaces),
      allowedValues: TextTemplate.allowedValues(for: .spaces)
    )
    let runs = template.renderRuns(
      ["name": "current"],
      entries: [
        ["name": "Code", "active": "true"], ["name": "Web", "active": "false"],
      ]
    )

    #expect(runs.map(\.text) == ["[", "*Code, ", "Web", "]"])
    #expect(runs.map(\.entry) == [nil, 0, 1, nil])

    let fallback = try TextTemplate(
      "{{^workspaces}}{{value}}{{/workspaces}}",
      fields: TextTemplate.fields(for: .spaces)
    )

    #expect(fallback.render(["value": "Unavailable"]) == "Unavailable")
  }

  @Test("presentation(for:): display scope preserves active emphasis separately from global focus")
  func displayScope() {
    let state = SpacesState(
      displays: [
        .init(identifier: "a", spaces: [.init(id: 10)], activeID: 10),
        .init(identifier: "b", spaces: [.init(id: 20), .init(id: 30)], activeID: 30),
      ],
      focusedID: 10
    )
    var item = Item(
      id: "spaces",
      type: .spaces,
      text: "{{id}}: {{name}}/{{total}} {{#active}}A{{/active}}{{#focused}}F{{/focused}}",
      spaces: .init(scope: .display, tints: .init(active: "#FFFFFF"))
    )

    #expect(state.presentation(for: item, displayUUID: "b").text == "spaces: 2/2 A")

    item.text = "{{#workspaces}}{{workspaceId}}:{{index}}{{^last}} | {{/last}}{{/workspaces}}"
    let result = state.presentation(for: item, displayUUID: "b")

    #expect(result.text == "20:1 | 30:2")
    #expect(result.segmentSpacing == 0)
    #expect(result.segments.map(\.emphasized) == [false, true])
    #expect(result.segments[0].tint == nil)
    #expect(result.segments[1].tint == "#FFFFFF")
    #expect(result.tint == nil)
  }

  @Test("presentation(for:): filtered empty lists and unavailable snapshots use explicit fallbacks")
  func emptyLists() {
    let item = Item(
      id: "spaces",
      type: .spaces,
      text: "{{#workspaces}}{{name}}{{/workspaces}}{{^workspaces}}{{value}}{{/workspaces}}",
      spaces: .init(includeFullscreen: false)
    )
    let fullscreen = SpacesState(
      displays: [.init(identifier: "a", spaces: [.init(id: 10, fullscreen: true)], activeID: 10)],
      focusedID: 10
    )

    #expect(fullscreen.presentation(for: item).text == "Fullscreen")
    #expect(fullscreen.presentation(for: item).segments.isEmpty)
    #expect(SpacesState().presentation(for: item).text == "Spaces unavailable")

    var hidden = item
    hidden.text = "{{#workspaces}}{{#index=99}}{{name}}{{/index}}{{/workspaces}}"

    #expect(fullscreen.presentation(for: hidden).text.isEmpty)
    #expect(fullscreen.presentation(for: hidden).segments.isEmpty)
  }

  @Test("presentation(for:): Aerospace order and Yabai indexes remain provider data")
  func integrations() {
    let aero = AerospaceState(
      workspaces: [
        .init(name: "Web", focused: false, visible: false, monitor: 1),
        .init(name: "Code", focused: true, visible: true, monitor: 1),
      ],
      displays: [1: "a"],
      unavailable: nil
    )
    let item = Item(
      id: "a",
      type: .aerospace,
      text:
        "{{#workspaces}}{{index}}={{#name=Code}}Dev{{/name}}{{^name=Code}}{{name}}{{/name}}{{^last}},{{/last}}{{/workspaces}}"
    )
    let result = aero.presentation(for: item, displayUUID: nil)

    #expect(result.text == "1=Web,2=Dev")
    #expect(result.segments.map(\.emphasized) == [false, true])

    let yabai = YabaiState(
      workspaces: [
        .init(
          id: 5,
          index: 2,
          label: "Code",
          focused: true,
          visible: true,
          monitor: 1,
          fullscreen: false
        ),
        .init(
          id: 9,
          index: 4,
          label: nil,
          focused: false,
          visible: false,
          monitor: 1,
          fullscreen: false
        ),
      ],
      displays: [1: "a"],
      unavailable: nil
    )
    let y = Item(
      id: "y",
      type: .yabai,
      text: "{{#workspaces}}{{index}}:{{name}}/{{total}}{{^last}},{{/last}}{{/workspaces}}"
    )

    #expect(yabai.presentation(for: y, displayUUID: nil).text == "2:Code/2,4:4/2")
  }

  @Test(
    "Configuration.validate: invalid workspace sections fail validation",
    arguments: [
      "{{workspaces}}", "{{#separator}}x{{/separator}}",
      "{{#workspaces}}{{separator}}{{/workspaces}}",
      "{{#workspaces}}{{^separator}}x{{/separator}}{{/workspaces}}",
      "{{#workspaces}}{{#separator=x}}x{{/separator}}{{/workspaces}}",
      "{{#workspaces=yes}}x{{/workspaces}}",
      "{{#workspaces}}{{#workspaces}}x{{/workspaces}}{{/workspaces}}",
      "{{#workspaces}}{{^workspaces}}x{{/workspaces}}{{/workspaces}}",
      "{{#workspaces}}{{#active=yes}}x{{/active}}{{/workspaces}}",
    ]
  )
  func invalid(text: String) {
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(left: [Item(id: "spaces", type: .spaces, text: text)])
      ).validate()
    }
  }

  @Test("Configuration.validate: collections are rejected on other providers")
  func otherProviders() {
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(left: [
          Item(id: "cpu", type: .cpu, text: "{{#workspaces}}{{value}}{{/workspaces}}")
        ])
      ).validate()
    }
  }
}
