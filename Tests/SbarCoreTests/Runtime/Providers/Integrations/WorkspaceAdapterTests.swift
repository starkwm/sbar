import Foundation
import Testing

@testable import SbarCore

@Suite("WorkspaceAdapter")
struct WorkspaceAdapterTests {
  @Test("WorkspaceAdapter.yabaiLabel: falls back to the space index when the label is empty")
  func yabaiLabelFallsBackToSpaceIndexForEmptyLabel() throws {
    #expect(try WorkspaceAdapter.yabaiLabel(Data(#"{"index":2,"label":"work"}"#.utf8)) == "work")
    #expect(try WorkspaceAdapter.yabaiLabel(Data(#"{"index":2,"label":""}"#.utf8)) == "2")
  }
}
