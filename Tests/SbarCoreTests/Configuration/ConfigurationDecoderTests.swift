import Foundation
import Testing

@testable import SbarCore

@Suite("ConfigurationDecoder")
struct ConfigurationDecoderTests {
  @Test("decodes plain JSON configuration")
  func decodesJSON() throws {
    let data = Data(#"{"schemaVersion":1,"bar":{},"items":{}}"#.utf8)
    #expect(try ConfigurationDecoder.decode(from: data).bar == BarSettings())
  }
}
