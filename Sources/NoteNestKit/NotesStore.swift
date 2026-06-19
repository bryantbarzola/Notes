import Foundation
import Combine

@MainActor
public final class NotesStore: ObservableObject {
    @Published public private(set) var notes: [Note] = []
    private let folder: URL
    private let fm = FileManager.default

    public init(folder: URL) {
        self.folder = folder
    }

    public static func defaultFolder() -> URL {
        fm_home().appendingPathComponent("Notes", isDirectory: true)
    }

    public func ensureFolderExists() {
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    public func reload() {
        let urls = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let mdURLs = urls.filter { $0.pathExtension.lowercased() == "md" }

        let loaded: [(Note, Date)] = mdURLs.compactMap { url in
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date.distantPast
            return (Note(filename: url.lastPathComponent, content: content), modified)
        }

        notes = loaded.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    @discardableResult
    public func create(date: Date = Date()) -> Note {
        let existing = Set((try? fm.contentsOfDirectory(atPath: folder.path)) ?? [])
        let filename = timestampFilename(for: date, existing: existing)
        let url = folder.appendingPathComponent(filename)
        try? "".write(to: url, atomically: true, encoding: .utf8)
        let note = Note(filename: filename, content: "")
        notes.insert(note, at: 0)
        return note
    }

    public func updateContent(of id: String, to content: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].content = content
    }

    public func save(_ id: String) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        let url = folder.appendingPathComponent(note.filename)
        try? note.content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func saveAll() {
        for note in notes {
            let url = folder.appendingPathComponent(note.filename)
            try? note.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public func delete(_ id: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let url = folder.appendingPathComponent(notes[idx].filename)
        try? fm.removeItem(at: url)
        notes.remove(at: idx)
    }

    public func mostRecentEmptyNote() -> Note? {
        notes.first { $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public func neighborID(after id: String) -> String? {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return nil }
        if idx + 1 < notes.count {
            return notes[idx + 1].id   // the note that slides into this slot
        } else if idx - 1 >= 0 {
            return notes[idx - 1].id   // deleting the last → new last
        } else {
            return nil                 // it was the only note
        }
    }

    @discardableResult
    public func createOrReuseEmpty() -> Note {
        if let empty = mostRecentEmptyNote() {
            return empty
        }
        return create()
    }
}

private func fm_home() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
}
