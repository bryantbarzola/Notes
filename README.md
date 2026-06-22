# NoteNest

A lightweight, self-built native macOS notes app for daily work notes.
Sidebar list, an optional Sublime-style tab bar, dark mode (Ghostty
"Andromeda" palette), silent autosave. Built with Swift + SwiftUI.

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
- `⌘N` — new note (reuses an empty note instead of stacking blanks)
- `⌘⌫` — delete selected note (immediate, no confirmation, no undo)
- `⌘,` — Settings (toggle the tab bar)

## Settings
- **Show tab bar** — shows a Sublime-style tab strip above the editor; on by
  default. The sidebar is always available (collapse it with the native
  sidebar button).

## Scope
Daily notes only — no search (yet), no markdown preview. Notes are plain `.md`
files; the first line is the title.

## Future enhancements (deferred)
Planned, not yet built — captured here so the roadmap lives with the code:
- **Search across notes** — find text across all `.md` files (was an original
  goal; deferred to keep v1 simple).
- **First-line-as-larger-title styling** — render the note's first line bigger
  in the editor (needs a richer text view than `TextEditor`; `Theme.titleFontSize`
  is reserved for it).
