import Foundation
import Testing

@testable import SbarCore

@Suite("VerticalBarConfiguration")
struct VerticalBarConfigurationTests {
  @Test(
    "all edges round trip and missing or null dimensions retain their defaults",
    arguments: [BarPosition.top, .bottom, .left, .right]
  )
  func decoding(position: BarPosition) throws {
    for dimensions in ["", ",\"height\":null,\"width\":null"] {
      let data = Data(
        "{\"schemaVersion\":1,\"bar\":{\"position\":\"\(position.rawValue)\"\(dimensions)},\"items\":{}}"
          .utf8
      )
      let configuration = try ConfigurationDecoder.decode(from: data)
      try configuration.validate()
      #expect(configuration.bar.height == 32)
      #expect(configuration.bar.width == 32)
      #expect(configuration.bar.position == position)
      #expect(
        try ConfigurationDecoder.decode(from: JSONEncoder().encode(configuration)) == configuration
      )
    }
  }

  @Test("vertical width bounds match the schema and validate on every edge")
  func widthValidation() throws {
    let schema = try #require(
      JSONSerialization.jsonObject(with: ConfigurationSchema.data()) as? [String: Any]
    )
    let root = try #require(schema["properties"] as? [String: Any])
    let bar = try #require(root["bar"] as? [String: Any])
    let properties = try #require(bar["properties"] as? [String: Any])
    let width = try #require(properties["width"] as? [String: Any])
    #expect(width["minimum"] as? Double == 20)
    #expect(width["maximum"] as? Double == 96)
    #expect(width["default"] as? Double == 32)
    let position = try #require(properties["position"] as? [String: Any])
    let edges = try #require(position["enum"] as? [Any])
    #expect(Set(edges.compactMap { $0 as? String }) == ["top", "bottom", "left", "right"])
    for edge in [BarPosition.top, .bottom, .left, .right] {
      for value in [20.0, 32.0, 96.0] {
        try Configuration(bar: .init(position: edge, width: value), items: .init()).validate()
      }
      for value in [19.0, 97.0, .infinity, .nan] {
        #expect(throws: (any Error).self) {
          try Configuration(bar: .init(position: edge, width: value), items: .init()).validate()
        }
      }
    }
  }
}
