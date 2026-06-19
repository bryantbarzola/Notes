# NoteNest (Swift Redesign) — Design Spec

**Date:** 2026-06-18
**Status:** Approved design, ready for implementation plan
**Supersedes:** `2026-06-18-notenest-design.md` (Python/PySide6 MVP)

## Background

The Python/PySide6 MVP worked functionally (autosave, search, tests) but had a
poor UI: nested "box-in-box" frames, a redundant duplicate title (sidebar +
tab), tabs that couldn't be closed or renamed, and notes stuck as "untitled."
After manual review, the decision was made to rebuild natively. This spec
defines the replacement.

## Purpose

A native macOS notes app for daily work notes — a self-built, work-approved
Sublime Text replacement. Clean, minimal, fast. Scope is intentionally small: a
notes app, not a code editor.

## Tech Stack

- **Language:** Swift 6
- **UI:** SwiftUI (native macOS), dark appearance
- **Build:** Xcode toolchain (Xcode 26.5 installed; `xcodebuild` available).
  Built and run from the command line via `xcodebuild` / an Xcode project.
- **Testing:** Swift Testing (or XCTest) for logic modules
- **Platform:** macOS (Apple Silicon, arm64)

## Key Decisions (from brainstorming)

1. **Sidebar-only** — one note shown at a time; NO tabs. Kills the box-in-box
   and duplicate-title problems at the root.
2. **First line = title** — the note's title (shown in the sidebar) is its
   first line of text. No manual naming or renaming.
3. **Timestamp filenames** — files are named at creation, e.g.
   `2026-06-18-2147.md`, and never rename. Titles come from the first line.
4. **Silent autosave** — saves continuously (debounced) and on quit. No save
   button, no save indicator, no status bar.
5. **Minimal layout** — thin sidebar, subtle 1px divider, title rendered larger
   at the top of the editor, generous padding (Bear / iA Writer feel).
6. **Delete supported** — notes can be deleted (with confirmation), so the
   folder doesn't accumulate junk.
7. **No search in v1** — deferred. Clean bolt-on later if missed.

## Requirements

1. Lightweight & native (fast launch, low footprint)
2. Dark mode
3. Sidebar list of notes, one note shown at a time (no tabs)
4. First line becomes the note's title in the sidebar
5. Silent autosave + save-on-quit
6. Create new note; delete existing note (with confirm)
7. Self-built (this is what makes it work-approved)

## Core Behavior

### Notes folder
- Works on one fixed folder: `~/Notes`, created automatically if missing.
- Only `.md` files are listed/managed.

### Filenames & titles
- New note filename: creation timestamp `YYYY-MM-DD-HHMM.md`. If a file with
  that name already exists (two notes in the same minute), append a numeric
  suffix to keep it unique (e.g. `2026-06-18-2147-2.md`).
- A note's **title** = its first non-empty line of text, trimmed. If the note
  is empty or the first line is blank, the title shows "New Note".

### Launch
- On launch: open the most recently modified note. If `~/Notes` is empty,
  create one fresh note and open it.
- Window opens at a sensible default size (~900×600) and is resizable.

### Sidebar
- Lists all notes by title, most-recently-modified first.
- `+` button creates a new note and focuses the editor.
- Selected note is highlighted.
- Right-click row → Delete (with confirmation); `⌘⌫` deletes the selected note
  (with confirmation).

### Editor
- Shows the selected note's full text, fills the height.
- First line is rendered larger to read as a title; the rest is body text.
- Dark theme, comfortable padding.
- Editing updates the in-memory note; the sidebar title updates live as the
  first line changes.

### Saving
- Debounced autosave: writes a short delay after typing stops.
- Save-on-quit: flush any pending change when the app closes.
- No visible save UI.

### Shortcuts
- `⌘N` — new note
- `⌘⌫` — delete selected note (with confirm)

## Layout

```
┌─────────────────────────────────────────────┐
│ ●●●            NoteNest                       │  ← native title bar
├──────────────┬──────────────────────────────┤
│  Notes    +  │  Standup notes               │  ← first line as title (larger)
│              │                              │
│ [Standup no] │  - shipped the parser        │
│  Ideas       │  - review at 2pm             │  ← editor fills remaining height
│  Bug list    │  |                           │
│              │                              │
└──────────────┴──────────────────────────────┘
```

- Left: thin sidebar (note titles, `+`, delete), subtle 1px divider.
- Right: editor for the selected note.
- No tabs, no status bar, no save button.

## Architecture (files)

Each unit has one responsibility and a clear boundary.

| File | Responsibility | Depends on |
|------|---------------|------------|
| `NoteNestApp.swift` | App entry point, window/scene, dark appearance | ContentView |
| `Note.swift` | Note model: `filename`, `content`; computed `title` from first line | (none) |
| `NotesStore.swift` | ALL disk logic for `~/Notes`: list, load, create, save, delete `.md`; holds observable note list | Note |
| `Debouncer.swift` | Delays an action until input pauses (autosave) | (none) |
| `SidebarView.swift` | Note list + `+` + delete; binds to store | NotesStore |
| `EditorView.swift` | Text editor for the current note; first line styled as title | NotesStore, Debouncer |
| `ContentView.swift` | Split layout wiring sidebar + editor, current-selection state | NotesStore, SidebarView, EditorView |

**Design intent:** disk access lives only in `NotesStore`; the debounce/autosave
timing lives only in `Debouncer`; title derivation lives only in `Note`. Views
are thin and delegate to these.

### Data flow
`NotesStore` is an observable object holding `[Note]`. `ContentView` tracks the
currently selected note. `SidebarView` selects/creates/deletes via the store.
`EditorView` edits the current note's content and, through `Debouncer`, calls
`store.save(note)`. First-line edits recompute `Note.title`, which updates the
sidebar live. On quit, the app flushes any pending save.

## Error Handling

- Missing `~/Notes` → create it; create one fresh note on first launch.
- File deleted on disk while open → next save recreates it; a file that fails to
  load is skipped (not a crash).
- Delete → confirmation prompt to prevent accidental loss.
- Save failure → keep the in-memory buffer (never lose typed text); failures are
  non-fatal.

## Testing

- **Unit tests (logic):**
  - `NotesStore` — create/list/load/save/delete against a temp directory;
    list ordering by modified-time; empty-folder behavior.
  - `Note` — `title` from first non-empty line; "New Note" fallback for
    empty/blank first line; filename uniqueness suffixing.
  - `Debouncer` — fires the action once after a pause, coalesces rapid calls.
- **Manual verification (SwiftUI views):** build and run the app, confirm
  layout, typing, live title update, autosave (file content on disk), new/delete
  flows, launch-into-recent-note, and empty-folder first launch. (Given the
  previous UI issues, manual run-and-look is an explicit, required step.)

## Out of Scope (YAGNI)

- Search across notes (deferred to a later version)
- Tabs / multiple notes visible at once
- Syntax highlighting, markdown preview/rendering
- Opening arbitrary folders (fixed `~/Notes`)
- Tags, folders, sub-notes, attachments
- iCloud/sync, multi-window
- Save indicators / status bar

## Migration Notes

- The Python implementation (`src/notenest/`, `tests/`, `run.sh`,
  `requirements.txt`, `pytest.ini`, `.venv`) is **deleted** once the Swift app
  works. The implementation plan handles removal as an explicit step (after the
  Swift app is verified, so we never delete working code before its replacement
  is confirmed). Git history retains the Python version if ever needed.
- Existing `.md` files in `~/Notes` remain readable (the app reads any `.md`;
  the first line becomes the title regardless of how the file was named).
