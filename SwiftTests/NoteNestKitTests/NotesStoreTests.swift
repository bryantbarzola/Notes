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
