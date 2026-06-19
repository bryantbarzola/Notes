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
