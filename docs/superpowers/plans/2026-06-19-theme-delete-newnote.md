# Andromeda Backgrounds + Reliable Delete + ⌘N Reuse — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recolor NoteNest's backgrounds to match Ghostty's Andromeda theme, make `⌘N` reuse an empty note instead of stacking blanks, and give delete a sensible post-delete selection.

**Architecture:** Colors change in `Theme.swift` only. Two small pure helpers are added to `NotesStore` (`neighborID(after:)` and `createOrReuseEmpty()`) and unit-tested, then wired into `ContentView`'s `newNote()` and `confirmDelete()`. Disk access stays in `NotesStore`; colors stay in `Theme`.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, Swift Testing. macOS 14+.

## Global Constraints

- macOS 14+, Swift 6. Repo root: `~/Documents/personal/notenest`. Build/test from there.
- Swift code under `Sources/`; tests under `SwiftTests/NoteNestKitTests`.
- Only background colors change. Foreground, secondary text, and accent stay as-is.
- Editor background `Theme.background` = `#262a33` = `Color(red: 0.149, green: 0.165, blue: 0.200)`.
- Sidebar background `Theme.sidebarBackground` = `#1d2027` = `Color(red: 0.114, green: 0.125, blue: 0.153)`.
- Delete is keyboard-only (`⌘⌫`) + existing right-click; NO visible button.
- Post-delete selection: the note now at the deleted index (the next note), else the new last note, else (no notes remain) create one and select it.
- `⌘N` reuses `mostRecentEmptyNote()` if present (select it, no new file) else creates.
- ALL filesystem access stays in `NotesStore`. Safety hook BLOCKS any command containing `rm` (incl. `git rm`); stage with explicit `git add <paths>`, never `git add -A`.

---

### Task 1: Andromeda background colors

**Files:**
- Modify: `Sources/NoteNestKit/Theme.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: updated `Theme.background` / `Theme.sidebarBackground` values; all other tokens unchanged.

**Note:** Colors are visual — verified by build + the Task 4 manual check. No unit test.

- [ ] **Step 1: Update the two background colors**

In `Sources/NoteNestKit/Theme.swift`, replace these two lines:
```swift
    public static let background = Color(red: 0.12, green: 0.12, blue: 0.12)
    public static let sidebarBackground = Color(red: 0.09, green: 0.09, blue: 0.09)
```
with:
```swift
    // Ghostty "Andromeda" background (#262a33)
    public static let background = Color(red: 0.149, green: 0.165, blue: 0.200)
    // Slightly darker matching shade for the sidebar (#1d2027)
    public static let sidebarBackground = Color(red: 0.114, green: 0.125, blue: 0.153)
```
Leave `foreground`, `secondaryText`, `accent`, `titleFontSize`, `bodyFontSize` unchanged.

- [ ] **Step 2: Build to verify it compiles**

Run: `cd ~/Documents/personal/notenest && swift build`
Expected: Build complete (no errors).

- [ ] **Step 3: Run the full suite (no regressions)**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 18 tests pass (unchanged).

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/Theme.swift
git commit -m "feat: recolor backgrounds to Ghostty Andromeda (#262a33 / #1d2027)"
```

---

### Task 2: `NotesStore` helpers — `neighborID(after:)` and `createOrReuseEmpty()`

**Files:**
- Modify: `Sources/NoteNestKit/NotesStore.swift`
- Test: `SwiftTests/NoteNestKitTests/NotesStoreTests.swift`

**Interfaces:**
- Consumes: existing `notes` (newest-first), `create()`, `mostRecentEmptyNote()`.
- Produces:
  - `public func neighborID(after id: String) -> String?` — given a note id, returns the id to select **after** that note is deleted: the next note (the one currently after it, which slides into its slot); if it's the last, the previous note; if it's the only note (or id not found with count ≤ 1), `nil`. Pure read of the current `notes`; does NOT mutate.
  - `@discardableResult public func createOrReuseEmpty() -> Note` — if `mostRecentEmptyNote()` exists, return it (no new file); else `create()` a new note and return it.

- [ ] **Step 1: Write the failing tests**

Append to `SwiftTests/NoteNestKitTests/NotesStoreTests.swift`:
```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/Documents/personal/notenest && swift test --filter "neighbor"` then `swift test --filter "createOrReuse"`
Expected: FAIL — `NotesStore` has no member `neighborID` / `createOrReuseEmpty`.

- [ ] **Step 3: Add the implementations**

In `Sources/NoteNestKit/NotesStore.swift`, add these two methods inside the `NotesStore` class (e.g. after `mostRecentEmptyNote()`):
```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/Documents/personal/notenest && swift test --filter "neighbor"` then `swift test --filter "createOrReuse"`
Expected: PASS (3 neighbor + 2 createOrReuse).

- [ ] **Step 5: Run the full suite**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 23 tests pass (18 prior + 5 new).

- [ ] **Step 6: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/NotesStore.swift SwiftTests/NoteNestKitTests/NotesStoreTests.swift
git commit -m "feat: add neighborID(after:) and createOrReuseEmpty to NotesStore"
```

---

### Task 3: Wire `⌘N` reuse + post-delete selection into `ContentView`

**Files:**
- Modify: `Sources/NoteNestKit/ContentView.swift`

**Interfaces:**
- Consumes: `NotesStore.createOrReuseEmpty()`, `NotesStore.neighborID(after:)` (Task 2), existing `store.delete`, `store.create`, `store.notes`.
- Produces: `newNote()` reuses an empty note; `confirmDelete()` selects a sensible neighbor (or creates one if the list becomes empty). No new public API.

- [ ] **Step 1: Update `newNote()` to reuse an empty note**

In `Sources/NoteNestKit/ContentView.swift`, replace:
```swift
    private func newNote() {
        let note = store.create()
        selection = note.id
    }
```
with:
```swift
    private func newNote() {
        // Reuse an existing blank note instead of stacking new empties.
        let note = store.createOrReuseEmpty()
        selection = note.id
    }
```

- [ ] **Step 2: Update `confirmDelete()` for sensible post-delete selection**

Replace:
```swift
    private func confirmDelete() {
        guard let id = pendingDeleteID else { return }
        store.delete(id)
        if selection == id {
            selection = store.notes.first?.id
        }
        pendingDeleteID = nil
    }
```
with:
```swift
    private func confirmDelete() {
        guard let id = pendingDeleteID else { return }
        // Compute the neighbor BEFORE deleting, so we can land on it after.
        let neighbor = store.neighborID(after: id)
        store.delete(id)
        if selection == id {
            if let neighbor {
                selection = neighbor
            } else {
                // No notes left — create a fresh one so the editor is never empty.
                selection = store.create().id
            }
        }
        pendingDeleteID = nil
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd ~/Documents/personal/notenest && swift build`
Expected: Build complete.

- [ ] **Step 4: Run the full suite (no regressions)**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 23 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/ContentView.swift
git commit -m "feat: ⌘N reuses empty note; delete selects a sensible neighbor"
```

---

### Task 4: Manual verification (DEFER TO HUMAN)

**Files:** none (verification only).

Needs a real GUI/Dock; cannot be done headlessly.

- [ ] **Step 1: Build and run**

The human runs:
```bash
cd ~/Documents/personal/notenest && ./scripts/build-app.sh
```

- [ ] **Step 2: Verify the colors**
- Editor background is the Andromeda blue-charcoal (`#262a33`), matching Ghostty.
- Sidebar is a slightly darker matching shade (`#1d2027`); the two areas look uniform/flush, not jarringly two-tone.

- [ ] **Step 3: Verify delete + selection**
- Select a note in the middle of the list, press `⌘⌫` (Command + Backspace), confirm → the note is deleted and selection lands on the next note (not "nothing selected").
- Delete the last note → selection lands on the new last note.
- Delete until one remains, then delete it → a fresh empty note appears and is selected (editor never blank/unusable).

- [ ] **Step 4: Verify ⌘N no longer stacks empties**
- Note current files: `ls ~/Notes`.
- Press `⌘N` several times WITHOUT typing → no new empty `.md` files pile up (you keep landing on the one reusable blank).
- Type into it, then `⌘N` → a fresh note is created (the now-non-empty one was not reused).

- [ ] **Step 5: Confirm to the controller**
- Report pass/fail per check; screenshot the recolored window if convenient. If anything's off (e.g. color looks wrong), capture it before we finish the branch.

---

## Self-Review Notes

- **Spec coverage:**
  - Editor bg `#262a33`, sidebar bg `#1d2027`, other tokens unchanged (T1).
  - Delete keyboard-only with sensible post-delete selection: neighbor → new-last → create-if-empty (T2 `neighborID` + T3 `confirmDelete`).
  - `⌘N` reuse (T2 `createOrReuseEmpty` + T3 `newNote`).
  - Disk access stays in `NotesStore`; colors only in `Theme` (boundaries kept).
  - Manual color + delete + ⌘N checks (T4).
- **Placeholder scan:** No TBD/TODO; every code step has complete code. T4 is an explicit human GUI check, consistent with prior tasks.
- **Type consistency:** `neighborID(after:) -> String?` and `createOrReuseEmpty() -> Note` defined in T2, consumed in T3. `store.delete`, `store.create`, `store.notes`, `mostRecentEmptyNote()` match current code (verified against the files). `Theme` token names unchanged.
- **Test count:** prior = 18; T2 adds 5 → 23 through T3 (T1/T3 add no Swift tests). Verified prior count from `swift test` (18).
- **Neighbor semantics check:** notes are newest-first; after removing index i, the element formerly at i+1 occupies slot i, so `notes[i+1]` is the correct "next" pre-deletion. Deleting the last (no i+1) falls to `notes[i-1]` (new last). Only note → nil → caller creates. Matches spec.
- **Hook caveat:** `rm` ban noted; all staging uses explicit `git add`.
