import Testing
import Foundation
@testable import NoteNestKit

private func tempFolder() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("notenest-tests-\(UUID().uuidString)", isDirectory: true)
    return url
}

@MainActor @Test func ensureFolderCreatesIt() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    #expect(FileManager.default.fileExists(atPath: folder.path))
}

@MainActor @Test func createWritesFileAndInsertsAtFront() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    #expect(store.notes.count == 1)
    #expect(store.notes.first?.id == note.id)
    #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent(note.filename).path))
}

@MainActor @Test func saveWritesContentToDisk() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    store.updateContent(of: note.id, to: "Hello world")
    store.save(note.id)
    let onDisk = try? String(contentsOf: folder.appendingPathComponent(note.filename), encoding: .utf8)
    #expect(onDisk == "Hello world")
}

@MainActor @Test func updateContentRecomputesTitleInMemory() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    store.updateContent(of: note.id, to: "My Title\nbody")
    #expect(store.notes.first?.title == "My Title")
}

@MainActor @Test func deleteRemovesFileAndNote() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    store.delete(note.id)
    #expect(store.notes.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent(note.filename).path))
}

@MainActor @Test func reloadOnlyReadsMarkdownFiles() {
    let folder = tempFolder()
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try? "note".write(to: folder.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
    try? "ignore".write(to: folder.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
    let store = NotesStore(folder: folder)
    store.reload()
    #expect(store.notes.count == 1)
    #expect(store.notes.first?.filename == "a.md")
}

@MainActor @Test func saveAllPersistsAllInMemoryNotes() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()

    let note1 = store.create()
    let note2 = store.create()

    store.updateContent(of: note1.id, to: "First note content")
    store.updateContent(of: note2.id, to: "Second note content")

    store.saveAll()

    let content1 = try? String(contentsOf: folder.appendingPathComponent(note1.filename), encoding: .utf8)
    let content2 = try? String(contentsOf: folder.appendingPathComponent(note2.filename), encoding: .utf8)

    #expect(content1 == "First note content")
    #expect(content2 == "Second note content")
}

@MainActor
@Test func mostRecentEmptyReturnsNilWhenAllHaveContent() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create()
    store.updateContent(of: a.id, to: "has content")
    #expect(store.mostRecentEmptyNote() == nil)
}

@MainActor
@Test func mostRecentEmptyReturnsAnEmptyNote() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create()  // empty by default
    #expect(store.mostRecentEmptyNote()?.id == a.id)
}

@MainActor
@Test func mostRecentEmptyTreatsWhitespaceAsEmpty() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create()
    store.updateContent(of: a.id, to: "   \n\t  ")
    #expect(store.mostRecentEmptyNote()?.id == a.id)
}

@MainActor
@Test func mostRecentEmptyPicksNewestEmptyAmongMixed() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    // create() inserts at front, so the LAST created is newest (index 0).
    let older = store.create()
    store.updateContent(of: older.id, to: "content")
    let newerEmpty = store.create()  // empty, now at front
    #expect(store.mostRecentEmptyNote()?.id == newerEmpty.id)
}

@MainActor
@Test func neighborAfterMiddleIsNextNote() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    // create() inserts at front, so after these three calls order is [c, b, a].
    let a = store.create(); store.updateContent(of: a.id, to: "a")
    let b = store.create(); store.updateContent(of: b.id, to: "b")
    let c = store.create(); store.updateContent(of: c.id, to: "c")
    // notes == [c, b, a]; deleting b (index 1) should select the note now at
    // index 1, which is a.
    #expect(store.neighborID(after: b.id) == a.id)
}

@MainActor
@Test func neighborAfterLastIsPreviousNote() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create(); store.updateContent(of: a.id, to: "a")
    let b = store.create(); store.updateContent(of: b.id, to: "b")
    // notes == [b, a]; a is last → deleting a selects the new last, b.
    #expect(store.neighborID(after: a.id) == b.id)
}

@MainActor
@Test func neighborOfOnlyNoteIsNil() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create()
    #expect(store.neighborID(after: a.id) == nil)
}

@MainActor
@Test func createOrReuseReturnsExistingEmptyWithoutGrowing() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let empty = store.create()  // empty
    let before = store.notes.count
    let reused = store.createOrReuseEmpty()
    #expect(reused.id == empty.id)
    #expect(store.notes.count == before)  // did not create another
}

@MainActor
@Test func createOrReuseCreatesWhenNoEmptyExists() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create(); store.updateContent(of: a.id, to: "content")
    let before = store.notes.count
    let made = store.createOrReuseEmpty()
    #expect(made.id != a.id)
    #expect(store.notes.count == before + 1)
}
