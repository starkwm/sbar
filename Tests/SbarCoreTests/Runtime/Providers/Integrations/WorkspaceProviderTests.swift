import Foundation
import Testing

@testable import SbarCore

@Suite("WorkspaceProvider")
struct WorkspaceProviderTests {
  @Test("WorkspaceProvider.yabaiLabel: falls back to the space index when the label is empty")
  func yabaiLabelFallsBackToSpaceIndexForEmptyLabel() throws {
    #expect(try WorkspaceProvider.yabaiLabel(Data(#"{"index":2,"label":"work"}"#.utf8)) == "work")
    #expect(try WorkspaceProvider.yabaiLabel(Data(#"{"index":2,"label":""}"#.utf8)) == "2")
  }
}
