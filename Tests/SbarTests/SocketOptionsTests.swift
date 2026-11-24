import ArgumentParser
import Darwin
import Foundation
import SbarCore
import Testing

@testable import Sbar

@Suite("SocketOptions")
struct SocketOptionsTests {
  @Test("Replies are flushed verbatim and a daemon error sets the exit status")
  func writesReplies() throws {
    let output = try #require(tmpfile())
    defer { fclose(output) }
    let lines = [
      #" { "value": "café\n", "extra": 1e2, "ok": true } "#,
      #"{ "error": "denied", "ok": false }"#,
    ]
    var expected = Data()
    for line in lines {
      let bytes = Data(line.utf8)
      let response = try JSONDecoder().decode(ControlResponse.self, from: bytes)
      if response.ok {
        try SocketOptions.write(response, line: bytes, to: output)
      } else {
        #expect(throws: ExitCode(1)) {
          try SocketOptions.write(response, line: bytes, to: output)
        }
      }

      expected.append(bytes)
      expected.append(10)
      // Read the underlying descriptor while the stdio stream is still open and buffered.
      var actual = [UInt8](repeating: 0, count: expected.count + 1)
      let count = pread(fileno(output), &actual, actual.count, 0)
      #expect(count == expected.count)
      #expect(actual.prefix(expected.count).elementsEqual(expected))
    }
  }
}
