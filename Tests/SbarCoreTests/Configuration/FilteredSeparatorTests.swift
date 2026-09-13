import Testing

@testable import SbarCore

@Suite("Filtered separators")
struct FilteredSeparatorTests {
  @Test(
    "separators follow rendered entries and retain source identities",
    arguments: [
      [false, true, false, true, false], [true, false, false, false, false],
      [false, false, false, false, true], [false, false, false, false, false],
    ]
  )
  func filtering(shown: [Bool]) throws {
    let template = try TextTemplate(
      "{{#services}}{{#connected}}{{name}}{{/connected}}{{#separator}}, {{/separator}}{{/services}}",
      fields: TextTemplate.fields(for: .vpn)
    )
    let entries = shown.enumerated().map {
      ["connected": String($0.element), "name": String($0.offset)]
    }
    let runs = template.renderRuns([:], entries: entries)
    let selected = shown.indices.filter { shown[$0] }
    #expect(runs.map(\.text).joined() == selected.map(String.init).joined(separator: ", "))
    #expect(runs.filter { !$0.separator }.compactMap(\.entry) == selected)
  }

  @Test("independent loops and symbol-only entries keep their separators")
  func loops() throws {
    let template = try TextTemplate(
      "{{#transfers}}{{symbol}}{{#separator}}|{{/separator}}{{/transfers}}/{{#transfers}}{{#direction=upload}}U{{/direction}}{{#separator}}|{{/separator}}{{/transfers}}",
      fields: TextTemplate.fields(for: .throughput)
    )
    let runs = template.renderRuns(
      [:],
      entries: [["direction": "download"], ["direction": "upload"]]
    )
    #expect(runs.map(\.text).joined() == "|/U")
    #expect(runs.filter(\.symbol).count == 2)
  }
}
