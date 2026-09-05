import Foundation
import Testing

@testable import SbarCore

@Suite("ActionRunner")
struct ActionRunnerTests {
  @MainActor @Test("expand(_:environment:): expands paths in a single pass")
  func expandPathsInSinglePass() {
    #expect(
      ActionRunner.expand("${ROOT}/tool", environment: ["ROOT": "${OTHER}", "OTHER": "/tmp"])
        == "${OTHER}/tool"
    )
  }
}
