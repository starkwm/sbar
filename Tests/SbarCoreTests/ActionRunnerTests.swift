import Foundation
import Testing

@testable import SbarCore

struct ActionRunnerTests {
  @MainActor @Test("Path expansion is single-pass")
  func pathExpansion() {
    #expect(
      ActionRunner.expand("${ROOT}/tool", environment: ["ROOT": "${OTHER}", "OTHER": "/tmp"])
        == "${OTHER}/tool"
    )
  }
}
