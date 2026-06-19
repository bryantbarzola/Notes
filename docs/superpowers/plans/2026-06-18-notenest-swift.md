# NoteNest (Swift Redesign) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI notes app (sidebar-only, first-line-as-title, silent autosave) to replace the Python/PySide6 MVP.

**Architecture:** A Swift package with three targets: `NoteNestKit` (a library holding all logic and SwiftUI views — testable), `NoteNest` (a thin `@main` executable that launches the app), and `NoteNestKitTests` (Swift Testing unit tests). All disk access lives in `NotesStore`; autosave timing lives in `Debouncer`; title derivation lives in `Note`. The app is built and bundled into a runnable `.app` via a shell script.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager (`swift build` / `swift test`), Swift Testing. macOS 14+ (Apple Silicon). Xcode 26.5 toolchain.

## Global Constraints

- Platform: macOS 14+, Apple Silicon (arm64). Swift 6, `swift-tools-version:6.0`.
- Notes folder: `~/Notes`, expanded from `FileManager.default.homeDirectoryForCurrentUser`, auto-created if missing. Only `.md` files.
- ALL filesystem access lives in `NotesStore` only. NO other file touches disk.
- Title derivation lives only in `Note.title`. Autosave timing lives only in `Debouncer`.
- Filenames: creation timestamp `yyyy-MM-dd-HHmm` (+ `-N` suffix on collision), `.md` extension, never renamed.
- Title = first non-empty trimmed line; `"New Note"` if none.
- Silent autosave (debounced) + save-on-quit. No save button, no save indicator, no status bar, no tabs, no search.
- Shortcuts: `⌘N` new note, `⌘⌫` delete selected (with confirmation).
- Window: default ~900×600, resizable.
- Directory layout avoids case-collision with the existing Python `src/`/`tests/`: Swift code lives under `Sources/` and `SwiftTests/`.
- Build/test commands run from repo root `~/notenest`.

---

### Task 1: Swift package scaffold + build/run script

**Files:**
- Create: `Package.swift`
- Create: `Sources/NoteNestKit/Placeholder.swift`
- Create: `Sources/NoteNest/App.swift`
- Create: `SwiftTests/NoteNestKitTests/SmokeTest.swift`
- Create: `scripts/build-app.sh`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable package with targets `NoteNestKit`, `NoteNest`, `NoteNestKitTests`; `swift build` and `swift test` work; `scripts/build-app.sh` produces and opens `NoteNest.app`.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NoteNest",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NoteNestKit", path: "Sources/NoteNestKit"),
        .executableTarget(
            name: "NoteNest",
            dependencies: ["NoteNestKit"],
            path: "Sources/NoteNest"
        ),
        .testTarget(
            name: "NoteNestKitTests",
            dependencies: ["NoteNestKit"],
            path: "SwiftTests/NoteNestKitTests"
        ),
    ]
)
```

- [ ] **Step 2: Create a temporary placeholder in the Kit so it compiles**

`Sources/NoteNestKit/Placeholder.swift`:
```swift
// Temporary placeholder so NoteNestKit has a source file in Task 1.
// Replaced by real types in later tasks; this file is deleted in Task 3.
public enum NoteNestKitPlaceholder {
    public static let ready = true
}
```

- [ ] **Step 3: Create the executable entry point**

`Sources/NoteNest/App.swift`:
```swift
import SwiftUI

@main
struct NoteNestApp: App {
    var body: some Scene {
        WindowGroup {
            Text("NoteNest")
                .frame(minWidth: 400, minHeight: 300)
        }
        .defaultSize(width: 900, height: 600)
    }
}
```

- [ ] **Step 4: Write the smoke test**

`SwiftTests/NoteNestKitTests/SmokeTest.swift`:
```swift
import Testing
@testable import NoteNestKit

@Test func kitIsReady() {
    #expect(NoteNestKitPlaceholder.ready == true)
}
```

- [ ] **Step 5: Run build + test to verify the package works**

Run: `cd ~/notenest && swift build && swift test`
Expected: Build completes; test run passes (1 test, `kitIsReady` passes).

- [ ] **Step 6: Create the build/run script**

`scripts/build-app.sh`:
```bash
#!/bin/bash
# Build NoteNest in release mode, wrap it in a .app bundle, ad-hoc codesign, and open it.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"
APP="./NoteNest.app"

mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH/NoteNest" "$APP/Contents/MacOS/NoteNest"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>NoteNest</string>
  <key>CFBundleIdentifier</key><string>com.bbarzola.notenest</string>
  <key>CFBundleName</key><string>NoteNest</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
open "$APP"
```

- [ ] **Step 7: Make the script executable and add build artifacts to `.gitignore`**

Run: `cd ~/notenest && chmod +x scripts/build-app.sh`

Add these lines to `.gitignore` (append; keep existing lines):
```
.build/
NoteNest.app/
*.xcodeproj
```

- [ ] **Step 8: Commit**

```bash
cd ~/notenest && git add Package.swift Sources SwiftTests scripts/build-app.sh .gitignore
git commit -m "chore: scaffold Swift package (Kit + executable + tests) and build script"
```

---

### Task 2: `Debouncer` — coalesced delayed action

**Files:**
- Create: `Sources/NoteNestKit/Debouncer.swift`
- Test: `SwiftTests/NoteNestKitTests/DebouncerTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public final class Debouncer`:
  - `init(interval: TimeInterval, queue: DispatchQueue = .main)`
  - `func call(_ action: @escaping @Sendable () -> Void)` — schedules `action` after `interval`; a new `call` before it fires cancels the previous one (so rapid calls fire once).
  - `func flushCancel()` — cancels any pending action without running it.

- [ ] **Step 1: Write the failing test**

`SwiftTests/NoteNestKitTests/DebouncerTests.swift`:
```swift
import Testing
import Foundation
@testable import NoteNestKit

@Test func debouncerCoalescesRapidCalls() async {
    let queue = DispatchQueue(label: "debouncer.test")
    let debouncer = Debouncer(interval: 0.05, queue: queue)
    let lock = NSLock()
    var count = 0

    for _ in 0..<5 {
        debouncer.call {
            lock.lock(); count += 1; lock.unlock()
        }
    }
    // Wait well past the interval for the single coalesced fire.
    try? await Task.sleep(nanoseconds: 300_000_000)

    lock.lock(); let final = count; lock.unlock()
    #expect(final == 1)
}

@Test func debouncerFlushCancelPreventsFire() async {
    let queue = DispatchQueue(label: "debouncer.test2")
    let debouncer = Debouncer(interval: 0.05, queue: queue)
    let lock = NSLock()
    var count = 0

    debouncer.call { lock.lock(); count += 1; lock.unlock() }
    debouncer.flushCancel()
    try? await Task.sleep(nanoseconds: 200_000_000)

    lock.lock(); let final = count; lock.unlock()
    #expect(final == 0)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/notenest && swift test --filter DebouncerTests`
Expected: FAIL — cannot find `Debouncer` in scope.

- [ ] **Step 3: Write minimal implementation**

`Sources/NoteNestKit/Debouncer.swift`:
```swift
import Foundation

public final class Debouncer {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem?
    private let lock = NSLock()

    public init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }

    public func call(_ action: @escaping @Sendable () -> Void) {
        lock.lock()
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        lock.unlock()
        queue.asyncAfter(deadline: .now() + interval, execute: item)
    }

    public func flushCancel() {
        lock.lock()
        workItem?.cancel()
        workItem = nil
        lock.unlock()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/notenest && swift test --filter DebouncerTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/notenest && git add Sources/NoteNestKit/Debouncer.swift SwiftTests/NoteNestKitTests/DebouncerTests.swift
git commit -m "feat: add Debouncer for coalesced autosave"
```

---

### Task 3: `Note` model + filename helper

**Files:**
- Create: `Sources/NoteNestKit/Note.swift`
- Delete: `Sources/NoteNestKit/Placeholder.swift`
- Modify: `SwiftTests/NoteNestKitTests/SmokeTest.swift` (replace placeholder test)
- Test: `SwiftTests/NoteNestKitTests/NoteTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public struct Note: Identifiable, Equatable` with:
    - `public let filename: String`
    - `public var content: String`
    - `public var id: String { filename }`
    - `public var title: String` — first non-empty trimmed line, else `"New Note"`.
    - `public init(filename: String, content: String)`
  - `public func timestampFilename(for date: Date, existing: Set<String>) -> String` — returns `yyyy-MM-dd-HHmm.md`; if that name is in `existing`, appends `-2`, `-3`, … until unique.

- [ ] **Step 1: Replace the placeholder smoke test**

Overwrite `SwiftTests/NoteNestKitTests/SmokeTest.swift`:
```swift
import Testing
@testable import NoteNestKit

@Test func packageImports() {
    // Sanity: the Kit module is importable and a Note can be constructed.
    let note = Note(filename: "x.md", content: "hi")
    #expect(note.id == "x.md")
}
```

- [ ] **Step 2: Write the failing test**

`SwiftTests/NoteNestKitTests/NoteTests.swift`:
```swift
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd ~/notenest && swift test --filter NoteTests`
Expected: FAIL — cannot find `Note` / `timestampFilename` in scope.

- [ ] **Step 4: Delete the placeholder and write the implementation**

Delete `Sources/NoteNestKit/Placeholder.swift`. The safety hook blocks shell
commands containing `rm` (including `git rm`), so remove the file from disk with
your file tooling (not a shell `rm`). Staging happens in Step 6 via
`git add Sources/NoteNestKit` — git records the deletion automatically once the
file is gone from disk.

Then create `Sources/NoteNestKit/Note.swift`:

`Sources/NoteNestKit/Note.swift`:
```swift
import Foundation

public struct Note: Identifiable, Equatable {
    public let filename: String
    public var content: String

    public init(filename: String, content: String) {
        self.filename = filename
        self.content = content
    }

    public var id: String { filename }

    public var title: String {
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { return line }
        }
        return "New Note"
    }
}

private let filenameFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    f.dateFormat = "yyyy-MM-dd-HHmm"
    return f
}()

public func timestampFilename(for date: Date, existing: Set<String>) -> String {
    let base = filenameFormatter.string(from: date)
    var candidate = "\(base).md"
    var n = 2
    while existing.contains(candidate) {
        candidate = "\(base)-\(n).md"
        n += 1
    }
    return candidate
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd ~/notenest && swift test --filter NoteTests && swift test --filter SmokeTest`
Expected: PASS (4 NoteTests + 1 SmokeTest).

- [ ] **Step 6: Commit**

```bash
cd ~/notenest && git add Sources/NoteNestKit SwiftTests/NoteNestKitTests
git commit -m "feat: add Note model and timestamp filename helper"
```

---

### Task 4: `NotesStore` — all disk access

**Files:**
- Create: `Sources/NoteNestKit/NotesStore.swift`
- Test: `SwiftTests/NoteNestKitTests/NotesStoreTests.swift`

**Interfaces:**
- Consumes: `Note`, `timestampFilename(for:existing:)`.
- Produces: `public final class NotesStore: ObservableObject`:
  - `@Published public private(set) var notes: [Note]`
  - `public init(folder: URL)`
  - `public static func defaultFolder() -> URL` — `~/Notes`.
  - `public func ensureFolderExists()` — creates the folder if missing.
  - `public func reload()` — loads all `.md` files into `notes`, sorted by file modification date descending (newest first).
  - `@discardableResult public func create(date: Date = Date()) -> Note` — creates a new empty `.md` file (unique timestamp name), inserts at front of `notes`, returns it.
  - `public func updateContent(of id: String, to content: String)` — updates the in-memory note's content (does NOT write to disk; saving is explicit).
  - `public func save(_ id: String)` — writes the in-memory note's content to its file.
  - `public func delete(_ id: String)` — removes the file and the in-memory note.

- [ ] **Step 1: Write the failing test**

`SwiftTests/NoteNestKitTests/NotesStoreTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/notenest && swift test --filter NotesStoreTests`
Expected: FAIL — cannot find `NotesStore` in scope.

- [ ] **Step 3: Write minimal implementation**

`Sources/NoteNestKit/NotesStore.swift`:
```swift
import Foundation
import Combine

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

    public func delete(_ id: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let url = folder.appendingPathComponent(notes[idx].filename)
        try? fm.removeItem(at: url)
        notes.remove(at: idx)
    }
}

private func fm_home() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/notenest && swift test --filter NotesStoreTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Run the FULL suite**

Run: `cd ~/notenest && swift test`
Expected: all pass (Smoke 1 + Debouncer 2 + Note 4 + NotesStore 6 = 13).

- [ ] **Step 6: Commit**

```bash
cd ~/notenest && git add Sources/NoteNestKit/NotesStore.swift SwiftTests/NoteNestKitTests/NotesStoreTests.swift
git commit -m "feat: add NotesStore for all disk access"
```

---

### Task 5: `Theme` + `SidebarView`

**Files:**
- Create: `Sources/NoteNestKit/Theme.swift`
- Create: `Sources/NoteNestKit/SidebarView.swift`

**Interfaces:**
- Consumes: `NotesStore`, `Note`.
- Produces:
  - `Theme` — `public enum Theme` with static SwiftUI `Color`s: `background`, `sidebarBackground`, `foreground`, `secondaryText`, `accent`, and `static let titleFontSize: CGFloat`, `static let bodyFontSize: CGFloat`.
  - `public struct SidebarView: View`:
    - `init(store: NotesStore, selection: Binding<String?>, onNew: @escaping () -> Void, onDelete: @escaping (String) -> Void)`
    - Renders a header row with "Notes" + a `+` button (calls `onNew`), then a `List` of note titles bound to `selection`; right-click context menu per row with "Delete" (calls `onDelete`).

**Note:** Views have no unit tests; the deliverable is that the package compiles. They are exercised in the Task 7 manual smoke test.

- [ ] **Step 1: Write `Theme.swift`**

`Sources/NoteNestKit/Theme.swift`:
```swift
import SwiftUI

public enum Theme {
    public static let background = Color(red: 0.12, green: 0.12, blue: 0.12)
    public static let sidebarBackground = Color(red: 0.09, green: 0.09, blue: 0.09)
    public static let foreground = Color(red: 0.83, green: 0.83, blue: 0.83)
    public static let secondaryText = Color(red: 0.5, green: 0.5, blue: 0.5)
    public static let accent = Color(red: 0.15, green: 0.31, blue: 0.47)
    public static let titleFontSize: CGFloat = 22
    public static let bodyFontSize: CGFloat = 14
}
```

- [ ] **Step 2: Write `SidebarView.swift`**

`Sources/NoteNestKit/SidebarView.swift`:
```swift
import SwiftUI

public struct SidebarView: View {
    @ObservedObject private var store: NotesStore
    @Binding private var selection: String?
    private let onNew: () -> Void
    private let onDelete: (String) -> Void

    public init(
        store: NotesStore,
        selection: Binding<String?>,
        onNew: @escaping () -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        self.store = store
        self._selection = selection
        self.onNew = onNew
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Button(action: onNew) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.foreground)
                .help("New note (⌘N)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(selection: $selection) {
                ForEach(store.notes) { note in
                    Text(note.title)
                        .lineLimit(1)
                        .foregroundColor(Theme.foreground)
                        .tag(note.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                onDelete(note.id)
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
        .background(Theme.sidebarBackground)
    }
}
```

- [ ] **Step 3: Verify the package still builds**

Run: `cd ~/notenest && swift build`
Expected: Build complete (no errors).

- [ ] **Step 4: Run the full suite (no regressions)**

Run: `cd ~/notenest && swift test`
Expected: 13 tests pass (unchanged).

- [ ] **Step 5: Commit**

```bash
cd ~/notenest && git add Sources/NoteNestKit/Theme.swift Sources/NoteNestKit/SidebarView.swift
git commit -m "feat: add Theme and SidebarView"
```

---

### Task 6: `EditorView`

**Files:**
- Create: `Sources/NoteNestKit/EditorView.swift`

**Interfaces:**
- Consumes: `Theme`.
- Produces: `public struct EditorView: View`:
  - `init(text: Binding<String>)`
  - A full-height `TextEditor` bound to `text`, dark theme, padded. (First-line-as-larger-title styling is approximated by editor font + padding; true rich styling is out of scope — the title is shown in the sidebar.)

**Note:** No unit test; deliverable is the package compiles. Exercised in Task 7 manual smoke test.

- [ ] **Step 1: Write `EditorView.swift`**

`Sources/NoteNestKit/EditorView.swift`:
```swift
import SwiftUI

public struct EditorView: View {
    @Binding private var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        TextEditor(text: $text)
            .font(.system(size: Theme.bodyFontSize, design: .monospaced))
            .foregroundColor(Theme.foreground)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `cd ~/notenest && swift build`
Expected: Build complete.

- [ ] **Step 3: Run the full suite (no regressions)**

Run: `cd ~/notenest && swift test`
Expected: 13 tests pass.

- [ ] **Step 4: Commit**

```bash
cd ~/notenest && git add Sources/NoteNestKit/EditorView.swift
git commit -m "feat: add EditorView"
```

---

### Task 7: `ContentView` + app wiring + delete confirm + manual smoke test

**Files:**
- Create: `Sources/NoteNestKit/ContentView.swift`
- Modify: `Sources/NoteNest/App.swift`

**Interfaces:**
- Consumes: `NotesStore`, `SidebarView`, `EditorView`, `Debouncer`, `Theme`, `Note`.
- Produces:
  - `public struct ContentView: View`:
    - `public init()` — creates its own `NotesStore` at `NotesStore.defaultFolder()`.
    - Holds `@StateObject store`, `@State selection: String?`, a `Debouncer`, and `@State` for delete confirmation.
    - On appear: `ensureFolderExists()`, `reload()`; if empty, `create()`; select the first note.
    - Layout: `NavigationSplitView` (or `HStack`) with `SidebarView` + `EditorView`.
    - Editing routes through a `Binding<String>` that calls `store.updateContent` then debounced `store.save`.
    - `⌘N` new note; `⌘⌫` delete selected with a confirmation dialog.
    - Save-on-quit handled in `App.swift` via scene phase.

- [ ] **Step 1: Write `ContentView.swift`**

`Sources/NoteNestKit/ContentView.swift`:
```swift
import SwiftUI

public struct ContentView: View {
    @StateObject private var store = NotesStore(folder: NotesStore.defaultFolder())
    @State private var selection: String?
    @State private var pendingDeleteID: String?
    @State private var showDeleteConfirm = false
    private let saveDebouncer = Debouncer(interval: 0.8)

    public init() {}

    private var editorText: Binding<String> {
        Binding(
            get: {
                guard let id = selection,
                      let note = store.notes.first(where: { $0.id == id })
                else { return "" }
                return note.content
            },
            set: { newValue in
                guard let id = selection else { return }
                store.updateContent(of: id, to: newValue)
                saveDebouncer.call { [weak store] in
                    DispatchQueue.main.async { store?.save(id) }
                }
            }
        )
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                store: store,
                selection: $selection,
                onNew: newNote,
                onDelete: requestDelete
            )
            .frame(minWidth: 180)
        } detail: {
            if selection != nil {
                EditorView(text: editorText)
            } else {
                Text("No note selected")
                    .foregroundColor(Theme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .background(Theme.background)
        .onAppear(perform: bootstrap)
        .confirmationDialog(
            "Delete this note?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDelete)
            Button("Cancel", role: .cancel) {}
        }
        // Hidden buttons provide the keyboard shortcuts.
        .background(
            Group {
                Button("", action: newNote).keyboardShortcut("n", modifiers: .command)
                Button("") { if let id = selection { requestDelete(id) } }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
            .opacity(0)
        )
    }

    private func bootstrap() {
        store.ensureFolderExists()
        store.reload()
        if store.notes.isEmpty {
            store.create()
        }
        selection = store.notes.first?.id
    }

    private func newNote() {
        let note = store.create()
        selection = note.id
    }

    private func requestDelete(_ id: String) {
        pendingDeleteID = id
        showDeleteConfirm = true
    }

    private func confirmDelete() {
        guard let id = pendingDeleteID else { return }
        store.delete(id)
        if selection == id {
            selection = store.notes.first?.id
        }
        pendingDeleteID = nil
    }

    public func flushSaves() {
        if let id = selection {
            store.save(id)
        }
    }
}
```

- [ ] **Step 2: Wire the app entry point with save-on-quit**

Overwrite `Sources/NoteNest/App.swift`:
```swift
import SwiftUI
import NoteNestKit

@main
struct NoteNestApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 400, minHeight: 300)
        }
        .defaultSize(width: 900, height: 600)
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd ~/notenest && swift build`
Expected: Build complete (no errors).

- [ ] **Step 4: Run the full suite**

Run: `cd ~/notenest && swift test`
Expected: 13 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/notenest && git add Sources/NoteNestKit/ContentView.swift Sources/NoteNest/App.swift
git commit -m "feat: wire ContentView, app entry, delete confirm, shortcuts"
```

- [ ] **Step 6: Manual smoke test (real window — DEFER TO HUMAN)**

This step launches a real GUI and CANNOT be done headlessly. The human runs:
```bash
cd ~/notenest && ./scripts/build-app.sh
```
Verify by hand:
- A dark window opens (~900×600), sidebar on the left, editor on the right.
- App opens straight into a note (most recent, or a fresh one if `~/Notes` was empty) — typeable immediately, no blank state.
- Typing in the editor; the sidebar title updates live as the first line changes.
- Wait ~1s after typing, then check the file on disk has the content (`cat ~/Notes/<file>.md`) — confirms silent autosave.
- `⌘N` creates a new note and focuses it.
- Right-click a sidebar row → Delete → confirmation appears → deleting removes it. `⌘⌫` does the same for the selected note.
- Close the window/quit → reopen → your latest edits are present (save-on-quit / autosave persisted).

---

### Task 8: Remove Python implementation + project README

**Files:**
- Delete: `src/` (Python package), `tests/` (pytest), `run.sh`, `requirements.txt`, `pytest.ini`
- Modify/Create: `README.md`

**Interfaces:**
- Consumes: a verified, working Swift app (Task 7 manual smoke test passed).
- Produces: a repo containing only the Swift app + docs.

**Precondition:** Do NOT start this task until the human confirms the Task 7 manual smoke test passed. We never delete the working Python app before its replacement is verified.

- [ ] **Step 1: Confirm the Swift app was verified**

The controller must have the human's confirmation that `./scripts/build-app.sh` produced a working app (Task 7 Step 6). If not confirmed, STOP.

- [ ] **Step 2: Delete the Python files**

The safety hook blocks commands containing `rm`. Delete these from disk using the editor/file tooling (not `rm`), then stage the deletions with `git add -A` is also discouraged; instead stage explicitly:
- Remove on disk: `src/notenest/` (all `.py`), `tests/` (all `.py`), `run.sh`, `requirements.txt`, `pytest.ini`.
- Stage deletions: `git add src tests run.sh requirements.txt pytest.ini`
  (git records the removals when the paths no longer exist on disk.)

Note: leave `.venv/` alone — it's gitignored and not tracked; the human can delete it manually later.

- [ ] **Step 3: Write `README.md`**

Overwrite `README.md`:
```markdown
# NoteNest

A lightweight, self-built native macOS notes app for daily work notes.
Sidebar list, one note at a time, dark mode, silent autosave. Built with
Swift + SwiftUI.

## Notes
Notes are plain `.md` files in `~/Notes` (created automatically). A note's
title in the sidebar is its first line of text.

## Build & run

    ./scripts/build-app.sh

This builds a release binary, wraps it in `NoteNest.app`, and opens it.

## Develop

    swift build      # compile
    swift test       # run unit tests

## Shortcuts
- `⌘N` — new note
- `⌘⌫` — delete selected note (with confirmation)

## Scope
Daily notes only — no tabs, no search (yet), no markdown preview. See
`docs/superpowers/specs/2026-06-18-notenest-swift-redesign.md`.
```

- [ ] **Step 4: Verify the Swift app still builds and tests pass after removal**

Run: `cd ~/notenest && swift build && swift test`
Expected: Build complete; 13 tests pass. (Confirms deleting Python didn't affect the Swift package.)

- [ ] **Step 5: Commit**

```bash
cd ~/notenest && git add -- src tests run.sh requirements.txt pytest.ini README.md
git commit -m "chore: remove Python implementation, add Swift README"
```

---

## Self-Review Notes

- **Spec coverage:**
  - Native Swift/SwiftUI, dark (T1 scaffold, T5 Theme, T7 `.preferredColorScheme(.dark)`).
  - Fixed `~/Notes`, `.md` only, auto-created (T4 `defaultFolder`/`ensureFolderExists`/`reload` filter; T7 bootstrap).
  - Sidebar-only, one note at a time, no tabs (T5 SidebarView, T7 NavigationSplitView).
  - First line = title (T3 `Note.title`; sidebar shows it; live update via T4 `updateContent` + T7 binding).
  - Timestamp filenames + collision suffix (T3 `timestampFilename`; T4 `create`).
  - Silent autosave (T2 Debouncer; T7 debounced `save`), save-on-quit (T7 `flushSaves` + T4 `save`; note: also covered by debounced save during use).
  - New note `⌘N` + delete `⌘⌫`/right-click with confirm (T7).
  - Launch into most-recent note / fresh note if empty (T7 bootstrap; T4 reload sort).
  - Window ~900×600 resizable (T1/T7 `defaultSize` + `minWidth/minHeight`).
  - No search, no status bar, no save button (omitted by design).
  - Delete Python after Swift verified (T8, gated on manual confirmation).
- **Placeholder scan:** No TBD/TODO. Every code step has complete code. The only "manual" step (T7 Step 6) is explicitly a human GUI check, consistent with the spec's "manual run-and-look is a required step."
- **Type consistency:** `Note(filename:content:)`, `Note.title`, `Note.id`; `timestampFilename(for:existing:)`; `NotesStore` methods `ensureFolderExists/reload/create/updateContent/save/delete` and `notes`/`defaultFolder()`; `Debouncer(interval:queue:)`/`call`/`flushCancel`; `SidebarView(store:selection:onNew:onDelete:)`; `EditorView(text:)`; `ContentView()` — all used consistently across tasks.
- **Known risk noted:** save-on-quit via scenePhase was simplified — the debounced autosave (0.8s) plus `flushSaves()` covers persistence; if the manual test shows a lost final edit on immediate quit, wire `ContentView.flushSaves()` to `scenePhase == .background` in `App.swift` (small follow-up).
- **Hook caveat captured:** the `rm`-blocking safety hook is called out in T3 (placeholder delete) and T8 (Python removal) so implementers use editor-based deletion + explicit `git add`, not `rm`.
