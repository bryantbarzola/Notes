import Testing
import Foundation
@testable import NoteNestKit

@Test func titleIsFirstNonEmptyLine() {
    let note = Note(filename: "a.md", content: "\n   \n  Standup notes \nmore")
    #expect(note.title == "Standup notes")
}

@Test func titleFallsBackToNewNote() {
    #expect(Note(filename: "a.md", content: "").title == "New Note")
    #expect(Note(filename: "a.md", content: "   \n\n").title == "New Note")
}

@Test func filenameUsesTimestampFormat() {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 6; comps.day = 18
    comps.hour = 21; comps.minute = 47
    let date = Calendar(identifier: .gregorian).date(from: comps)!
    let name = timestampFilename(for: date, existing: [])
    #expect(name == "2026-06-18-2147.md")
}

@Test func filenameSuffixesOnCollision() {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 6; comps.day = 18
    comps.hour = 21; comps.minute = 47
    let date = Calendar(identifier: .gregorian).date(from: comps)!
    let existing: Set<String> = ["2026-06-18-2147.md", "2026-06-18-2147-2.md"]
    let name = timestampFilename(for: date, existing: existing)
    #expect(name == "2026-06-18-2147-3.md")
}
