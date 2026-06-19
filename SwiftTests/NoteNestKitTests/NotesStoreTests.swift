import Testing
import Foundation
@testable import NoteNestKit

private func tempFolder() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("notenest-tests-\(UUID().uuidString)", isDirectory: true)
    return url
}

@Test func ensureFolderCreatesIt() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    #expect(FileManager.default.fileExists(atPath: folder.path))
}

@Test func createWritesFileAndInsertsAtFront() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    #expect(store.notes.count == 1)
    #expect(store.notes.first?.id == note.id)
    #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent(note.filename).path))
}

@Test func saveWritesContentToDisk() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    store.updateContent(of: note.id, to: "Hello world")
    store.save(note.id)
    let onDisk = try? String(contentsOf: folder.appendingPathComponent(note.filename), encoding: .utf8)
    #expect(onDisk == "Hello world")
}

@Test func updateContentRecomputesTitleInMemory() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    store.updateContent(of: note.id, to: "My Title\nbody")
    #expect(store.notes.first?.title == "My Title")
}

@Test func deleteRemovesFileAndNote() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let note = store.create()
    store.delete(note.id)
    #expect(store.notes.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent(note.filename).path))
}

@Test func reloadOnlyReadsMarkdownFiles() {
    let folder = tempFolder()
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try? "note".write(to: folder.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
    try? "ignore".write(to: folder.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
    let store = NotesStore(folder: folder)
    store.reload()
    #expect(store.notes.count == 1)
    #expect(store.notes.first?.filename == "a.md")
}
