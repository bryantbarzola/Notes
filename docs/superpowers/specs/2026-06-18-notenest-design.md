# NoteNest — Design Spec

**Date:** 2026-06-18
**Status:** Approved design, ready for implementation plan

## Purpose

A lightweight macOS desktop app for daily work notes, built to be a homemade,
self-maintainable replacement for Sublime Text (which is not work-approved).
Scope is intentionally small: a notes app, **not** a general code editor.

## Tech Stack

- **Language:** Python (the user's primary language, so it stays maintainable by them)
- **GUI toolkit:** PySide6 (Qt) — chosen for a polished, real-app look with proper
  dark theme and native-feeling tabs. One dependency to install.
- **Platform:** macOS (Darwin)

## Requirements

1. Lightweight
2. Dark mode
3. Tabs (multiple notes open at once)
4. Search across all note files
5. Self-built (this is what makes it work-approved)

## Core Behavior

### Notes folder
- App works on **one fixed folder**, default `~/Notes`.
- The folder is **created automatically** if it doesn't exist.
- Only `.txt` and `.md` files are listed/managed.

### Launch
- On launch, open the fixed folder and show a sidebar listing all notes.

### Tabs
- Click a file in the sidebar → opens in its own tab.
- Multiple tabs open simultaneously; switch and close tabs.
- A `+` action creates a new note.
- Unsaved changes shown as a `•` indicator on the tab.

### Editing
- Plain text editing (no syntax highlighting — out of scope).
- Dark theme, comfortable reading font.

### Saving (auto-save + manual)
- **Auto-save:** debounced — saves a moment after the user stops typing.
- **Manual:** `Cmd+S` saves the current tab immediately.
- **On quit:** save all unsaved tabs (safety net).
- Unsaved-changes dot on the tab; status bar shows save state.

### Search across files
- `Cmd+Shift+F` opens a search overlay/panel.
- Type a term → list every note containing it, with a preview line.
- Click a result → jump to that file (open tab) and the matching line.

## Screen Layout

```
┌─────────────────────────────────────────────────┐
│  [tab: 2026-06-18.md •] [tab: ideas.md]    [+]   │  ← tab bar
├──────────────┬──────────────────────────────────┤
│  Sidebar     │   Editor area                     │
│  (file list) │   (dark theme)                    │
│  2026-06-18  │                                   │
│  ideas       │                                   │
│  meeting     │                                   │
├──────────────┴──────────────────────────────────┤
│  ~/Notes · Saved ✓                               │  ← status bar
└─────────────────────────────────────────────────┘
```

- **Sidebar (left):** list of all notes; click to open.
- **Tab bar (top):** open notes; `•` = unsaved; `+` = new note.
- **Editor (center):** the active note.
- **Status bar (bottom):** folder path + save status.
- **Search:** overlay panel triggered by `Cmd+Shift+F`.

## Architecture (modules)

Each module has one clear job and a well-defined boundary:

| Module | Responsibility | Depends on |
|--------|---------------|------------|
| `main.py` | Start app, build window, wire components together | all below |
| `notes_folder.py` | All disk logic for `~/Notes`: list, read, write, create | (filesystem) |
| `editor_tabs.py` | Tab bar + editor widgets; open/close tabs; track dirty state | `notes_folder`, `theme` |
| `autosave.py` | Debounced auto-save, `Cmd+S`, save-on-quit | `notes_folder`, `editor_tabs` |
| `search.py` | Search across all notes; return matches + preview lines | `notes_folder` |
| `theme.py` | Dark theme: colors, fonts — centralized for easy tweaking | (none) |

**Design intent:** changing save behavior touches only `autosave.py`; changing
the look touches only `theme.py`. All filesystem access is isolated in
`notes_folder.py`.

## Error Handling

- Missing `~/Notes` folder → create it silently.
- File deleted on disk while open in a tab → on next save, recreate or warn in status bar.
- Unreadable/locked file → show a non-blocking message in the status bar, don't crash.
- Auto-save failure → surface in status bar; never lose the in-memory buffer.

## Testing

- `notes_folder.py` — unit tests against a temp directory (list/read/write/create).
- `search.py` — unit tests over a temp folder of fixture notes (matches, previews, no-match).
- `autosave.py` — test debounce triggers a write and save-on-quit flushes dirty buffers.
- GUI wiring (`editor_tabs`, `main`) — smoke-tested manually; logic kept thin and
  delegated to the testable modules above.

## Out of Scope (YAGNI)

- Syntax highlighting / code features
- Opening arbitrary folders (fixed `~/Notes` only, for now)
- Daily-note auto-creation
- Plugins, themes beyond the one dark theme
- Cross-platform packaging
