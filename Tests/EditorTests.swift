import Testing

@testable import StarkBar

@MainActor
struct EditorTests {
  @Test("Moving between sections preserves identity and inserts before the target")
  func move() {
    let editor = ConfigurationEditor()
    editor.move("app", to: .right, before: "clock")
    #expect(editor.draft.items.left.isEmpty)
    #expect(editor.draft.items.right.map(\.id) == ["divider", "app", "clock"])
    #expect(editor.selection == "app")
    #expect(editor.dirty)
    editor.move("app", to: .right, before: "app")
    #expect(editor.draft.items.right.map(\.id) == ["divider", "app", "clock"])
  }

  @Test("Invalid drafts are retained for correction and reload discards edits")
  func validation() {
    let editor = ConfigurationEditor()
    editor.draft.bar.height = 0
    #expect(editor.validationError != nil)
    #expect(editor.draft.bar.height == 0)
    editor.load(.default)
    #expect(!editor.dirty)
    #expect(editor.validationError == nil)
  }
}
