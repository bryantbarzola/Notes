# NoteNest

A lightweight, self-built notes app for macOS. Daily work notes with tabs,
dark mode, auto-save, and search across all notes.

## Setup

    python3 -m venv .venv
    .venv/bin/pip install -r requirements.txt

## Run

    ./run.sh

Notes live in `~/Notes` (created automatically).

## Shortcuts

- `Cmd+S` — save current note
- `Cmd+N` — new note
- `Cmd+Shift+F` — search across all notes

## Test

    .venv/bin/pytest
