import Foundation
import Testing

@testable import SbarCore

@Suite("RemindersConfiguration")
struct RemindersConfigurationTests {
  @Test("validate: defaults, round trips, invalid selections and schema agree")
  func configuration() throws {
    let item = try JSONDecoder().decode(
      Item.self,
      from: Data(
        ##"{"id":"tasks","type":"reminders","reminders":{"listIds":["work"],"lookaheadDays":3,"includeUndated":true,"symbols":{"dueToday":"star"},"tints":{"dueToday":"#112233"}}}"##
          .utf8
      )
    )
    try Configuration(bar: .init(), items: .init(right: [item])).validate()
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    #expect(RemindersConfiguration().resolvedLookaheadDays == 7)
    for json in [
      ##"{"listIds":[]}"##, ##"{"listIds":[" "]}"##, ##"{"listIds":["a","a"]}"##,
      ##"{"lookaheadDays":0}"##, ##"{"lookaheadDays":31}"##, ##"{"timeFormat":" "}"##,
      ##"{"symbols":{"bad":"star"}}"##, ##"{"tints":{"bad":"#112233"}}"##,
      ##"{"tints":{"empty":"red"}}"##,
    ] {
      #expect(throws: (any Error).self) {
        let settings = try JSONDecoder().decode(RemindersConfiguration.self, from: Data(json.utf8))
        try settings.validate(path: "reminders")
      }
    }
    #expect(throws: ConfigurationError.self) {
      try Configuration(
        bar: .init(),
        items: .init(right: [
          Item(id: "text", type: .text, reminders: .init())
        ])
      ).validate()
    }

    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let config = try #require(definitions["reminders"] as? [String: Any])
    let properties = try #require(config["properties"] as? [String: Any])
    let ids = try #require(properties["listIds"] as? [String: Any])
    #expect(ids["minItems"] as? Int == 1)
    #expect(ids["uniqueItems"] as? Bool == true)
    let horizon = try #require(properties["lookaheadDays"] as? [String: Any])
    #expect(horizon["minimum"] as? Int == 1)
    #expect(horizon["maximum"] as? Int == 30)
    let symbols = try #require(definitions["remindersSymbols"] as? [String: Any])
    let symbolProperties = try #require(symbols["properties"] as? [String: Any])
    #expect(
      Set(symbolProperties.keys).subtracting(["font", "size"])
        == Set(RemindersStatus.allCases.map(\.rawValue))
    )
    let itemSchema = try #require(definitions["item"] as? [String: Any])
    let itemProperties = try #require(itemSchema["properties"] as? [String: Any])
    #expect((itemProperties["reminders"] as? [String: String])?["$ref"] == "#/$defs/reminders")
  }
}

@Suite("ProviderRuntime")
@MainActor
struct RemindersRuntimeTests {
  @Test(
    "configure: shares collection with popup children and keeps filtered snapshots and values consistent"
  )
  func runtime() async throws {
    let now = Date()
    let lists = [
      ReminderList(id: "a", title: "A", sourceId: "s", sourceTitle: "Source"),
      ReminderList(id: "b", title: "B", sourceId: "s", sourceTitle: "Source"),
    ]
    let records = [
      ReminderRecord(id: "1", listId: "a", title: "A task", due: nil),
      ReminderRecord(id: "2", listId: "b", title: "B task", due: nil),
    ]
    var reads: [Set<String>?] = []
    let provider = RemindersProvider { ids, _ in
      reads.append(ids)
      return RemindersState(access: .empty, lists: lists, reminders: records, now: now)
    }
    let runtime = ProviderRuntime(reminders: provider)
    defer { runtime.stop() }
    let child = Item(
      id: "child",
      type: .reminders,
      reminders: .init(listIds: ["b"], includeUndated: true)
    )
    var manual = Item(
      id: "tasks",
      type: .reminders,
      text: "{{title}} · {{value}}",
      children: [child],
      reminders: .init(listIds: ["a"], includeUndated: true),
      refresh: .init(mode: .manual)
    )
    var events: [String: String] = [:]
    runtime.onValueChange = { events[$0] = $1 }
    runtime.configure(Configuration(bar: .init(), items: .init(right: [manual])))
    try await waitUntil { runtime.itemValues["child"] == "1 undated" }
    runtime.trigger("tasks")

    #expect(reads == [Set(["a", "b"])])
    #expect(runtime.presentation(for: manual)?.text == "A task · 1 undated")
    #expect(runtime.presentation(for: child)?.text == "1 undated")
    #expect(runtime.itemValues["tasks"] == "1 undated")
    #expect(events["tasks"] == "1 undated")

    runtime.updateReminders(RemindersState(access: .empty, lists: lists, now: now))
    #expect(runtime.presentation(for: manual)?.text == "A task · 1 undated")
    #expect(runtime.itemValues["child"] == "No reminders due")
    runtime.trigger("tasks")
    #expect(runtime.presentation(for: manual)?.text == " · No reminders due")

    runtime.updateReminders(
      RemindersState(access: .empty, lists: lists, reminders: records, now: now)
    )
    runtime.trigger("tasks")
    runtime.updateReminders(RemindersState(access: .unauthorized))
    #expect(runtime.presentation(for: manual)?.text == " · Reminders permission denied")
    #expect(runtime.itemValues["tasks"] == "Reminders permission denied")

    runtime.updateReminders(
      RemindersState(access: .empty, lists: lists, reminders: records, now: now)
    )
    manual.reminders?.listIds = ["b"]
    runtime.configure(Configuration(bar: .init(), items: .init(right: [manual])))
    try await waitUntil { reads.count == 2 }
    try await waitUntil { runtime.itemValues["child"] == "1 undated" }
    runtime.trigger("tasks")
    #expect(runtime.presentation(for: manual)?.text == "B task · 1 undated")

    runtime.updateReminders(RemindersState(access: .empty, lists: [], now: now))
    #expect(runtime.presentation(for: manual)?.text.contains("missing") == true)
    #expect(runtime.itemValues["tasks"]?.contains("missing") == true)

    runtime.configure(Configuration(bar: .init(), items: .init()))
    #expect(runtime.widgetStates[.reminders] == nil)
    #expect(runtime.itemValues["tasks"] == nil)
    #expect(runtime.itemValues["child"] == nil)
  }

  @Test("configure: changing presentation does not restart collection or clear other providers")
  func cosmeticChanges() async throws {
    var reads = 0
    let provider = RemindersProvider { _, _ in
      reads += 1
      return RemindersState(access: .empty)
    }
    let runtime = ProviderRuntime(reminders: provider)
    defer { runtime.stop() }
    var item = Item(id: "tasks", type: .reminders)
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))
    try await waitUntil { reads == 1 }
    runtime.updateWidgetState(.calendar(CalendarState(access: .unauthorized)), for: .calendar)
    item.text = "{{value}}!"
    runtime.configure(Configuration(bar: .init(), items: .init(right: [item])))

    #expect(reads == 1)
    if case .calendar(let state) = runtime.widgetStates[.calendar] {
      #expect(state.access == .unauthorized)
    } else {
      Issue.record("Calendar state was lost")
    }
    #expect(runtime.presentation(for: item)?.text == "No reminders due!")
  }
}
