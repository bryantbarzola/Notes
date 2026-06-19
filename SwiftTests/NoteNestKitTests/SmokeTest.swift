import Testing
@testable import NoteNestKit

@Test func packageImports() {
    // Sanity: the Kit module is importable and a Note can be constructed.
    let note = Note(filename: "x.md", content: "hi")
    #expect(note.id == "x.md")
}
