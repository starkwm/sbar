import Foundation
import Testing

@testable import SbarCore

@Suite("ConfigurationDecoder")
struct ConfigurationDecoderTests {
  @Test("normalization preserves strings, escapes, Unicode, and source positions")
  func preservesStringsAndPositions() throws {
    let source = #"""
      { /* café */ "url": "https://example.com/*path*/", // comment
        "text": "quote: \" // literal", "slash": "\\", "unicode": "日本語", }
      """#
    let result = try ConfigurationDecoder.normalized(Data(source.utf8))
    let value = try JSONDecoder().decode([String: String].self, from: result)
    #expect(value["url"] == "https://example.com/*path*/")
    #expect(value["text"] == "quote: \" // literal")
    #expect(value["slash"] == "\\")
    #expect(value["unicode"] == "日本語")
    #expect(result.count == source.utf8.count)
    #expect(
      Array(result.enumerated().filter { $0.element == 10 }.map(\.offset))
        == Array(source.utf8.enumerated().filter { $0.element == 10 }.map(\.offset))
    )
  }

  @Test("strips trailing commas across comments in nested arrays and objects")
  func stripsTrailingCommas() throws {
    let source = "{\"values\":[1, {\"nested\":[true,],}, /* end */\r\n],}// EOF"
    let normalized = try ConfigurationDecoder.normalized(Data(source.utf8))
    let expected = Data("{\"values\":[1, {\"nested\":[true ] }           \r\n] }      ".utf8)
    #expect(normalized == expected)
    _ = try JSONDecoder().decode(JSONValue.self, from: normalized)
  }

  @Test(
    "rejects malformed JSONC",
    arguments: [
      "[,]", "{,}", "[1,,]", "{\"x\":,}", "[1,/* comment */,]",
      "[1/* comment */2]", "{\"x\":true false}", "/* unfinished", "{} /* unfinished",
      "{\"x\":\"unfinished}", "[1,] garbage",
    ]
  )
  func rejectsMalformedInput(source: String) {
    #expect(throws: (any Error).self) {
      let data = try ConfigurationDecoder.normalized(Data(source.utf8))
      _ = try JSONDecoder().decode(JSONValue.self, from: data)
    }
  }

  @Test("plain JSON remains unchanged")
  func preservesJSON() throws {
    let data = Data(#"{"schemaVersion":1,"bar":{},"items":{}}"#.utf8)
    #expect(try ConfigurationDecoder.normalized(data) == data)
    #expect(try ConfigurationDecoder.decode(from: data).bar == BarSettings())
  }
}
