import Foundation
import Testing

@testable import SbarCore

@Suite("Tooltip templates")
struct TooltipTemplateTests {
  @Test("templates preserve newlines, escaped braces, and literal provider output")
  func rendering() throws {
    let template = try TooltipTemplate(
      "{{Track}}: {title}\n{artist} / {title}",
      type: .media
    )
    #expect(
      template.render(values: ["title": "Song {artist}", "artist": "Björk"])
        == "{Track}: Song {artist}\nBjörk / Song {artist}"
    )
    #expect(try TooltipTemplate("{{{id}}}", type: .text).render(values: ["id": "x"]) == "{x}")
    #expect(try TooltipTemplate("Plain text", type: .text).render(values: [:]) == "Plain text")
  }

  @Test("missing or blank values use a placeholder without treating zero as missing")
  func missingValues() throws {
    let template = try TooltipTemplate("{used} / {total}: {percentage}%", type: .memory)
    #expect(template.render(values: ["total": " \n", "percentage": "0"]) == "— / —: 0%")
  }

  @Test(
    "invalid templates identify the nested item and token",
    arguments: ["{title}", "{percent}", "{}", "{percentage", "percentage}", "{per{centage}"]
  )
  func invalidTemplates(source: String) {
    let item = Item(id: "cpu", type: .cpu, tooltip: source)
    let configuration = Configuration(
      bar: .init(),
      items: .init(left: [Item(id: "group", type: .group, children: [item])])
    )
    do {
      try configuration.validate()
      Issue.record("Expected invalid tooltip")
    } catch ConfigurationError.invalidValue(let path, let reason) {
      #expect(path == "items.left[0].children[0].tooltip")
      #expect(!reason.isEmpty)
      if source == "{title}" {
        #expect(reason.contains("'{title}'"))
        #expect(reason.contains("cpu"))
        #expect(reason.contains("percentage"))
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("tooltip configuration is optional and round trips templates and opt-outs")
  func configuration() throws {
    for value in ["null", "\"\"", #""{percentage}%\n{status}""#] {
      let data = Data("{\"id\":\"battery\",\"type\":\"battery\",\"tooltip\":\(value)}".utf8)
      let item = try JSONDecoder().decode(Item.self, from: data)
      try Configuration(bar: .init(), items: .init(right: [item])).validate()
      #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)
    }
    #expect(
      try JSONDecoder().decode(Item.self, from: Data(#"{"id":"x","type":"text"}"#.utf8)).tooltip
        == nil
    )
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        Item.self,
        from: Data(#"{"id":"x","type":"text","tooltip":false}"#.utf8)
      )
    }
  }

  @Test("the published schema accepts optional tooltip strings and null")
  func schema() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let definitions = try #require(schema["$defs"] as? [String: Any])
    let item = try #require(definitions["item"] as? [String: Any])
    let properties = try #require(item["properties"] as? [String: Any])
    let tooltip = try #require(properties["tooltip"] as? [String: Any])
    #expect(tooltip["type"] as? [String] == ["string", "null"])
    #expect((item["required"] as? [String])?.contains("tooltip") == false)
  }
}
