# NoteNest — Andromeda Backgrounds, Reliable Delete, ⌘N Reuse

**Date:** 2026-06-19
**Status:** Approved design, ready for implementation plan
**Builds on:** the shipped Swift app + the Dock-icon/launch-reuse enhancement.

## Purpose

Three small, related polish improvements driven by daily use:

1. **Match the editor background to Ghostty's Andromeda theme** so NoteNest
   looks at home next to the user's terminal, with a uniform dark UI.
2. **Make deleting a note easy and reliable** via the keyboard (no visible
   button), including sensible selection after a delete.
3. **Stop `⌘N` from leaving empty notes behind** by reusing an existing empty
   note instead of always creating a new blank file.

## Decisions (from brainstorming)

- **Backgrounds only** change color; text/foreground and selection colors stay
  as they are.
- Editor background = Andromeda's background `#262a33`.
- Sidebar background = a slightly darker matching shade `#1d2027` (≈25% darker)
  so the nav and editor read as one uniform UI with a subtle panel separation.
- **Delete = keyboard-only.** No visible trash button (explicitly declined).
  Keep `⌘⌫` (Command + Backspace) with the existing confirmation dialog.
- After a delete, selection moves to a neighboring note (never lands on
  "nothing selected" when notes remain).
- **`⌘N` reuses an empty note** when one exists (select it) instead of creating
  another blank — same principle as the launch reuse already shipped.

## Color Values

| Surface | Current | New |
|---------|---------|-----|
| Editor background (`Theme.background`) | `#1e1e1e`-ish | **`#262a33`** |
| Sidebar background (`Theme.sidebarBackground`) | darker grey | **`#1d2027`** |
| Foreground / text | — | unchanged |
| Selection / accent | — | unchanged |

`#262a33` = sRGB (0.149, 0.165, 0.200). `#1d2027` = sRGB (0.114, 0.125, 0.153).

## Behavior

### Delete (keyboard-only)
- `⌘⌫` while a note is selected → confirmation dialog → on confirm, delete the
  selected note's file and remove it from the list.
- **Post-delete selection:** after deleting, select the note that now occupies
  the deleted note's position (or the new last note if it was the last). If no
  notes remain, create a fresh note and select it (never leave the editor with
  no selection).
- The right-click context-menu Delete continues to work (unchanged); this spec
  only ensures the keyboard path and post-delete selection are solid.

### ⌘N reuse
- `⌘N` (new note): if `store.mostRecentEmptyNote()` returns a note, select that
  note instead of creating a new one; otherwise create a new note and select it.
- Net effect: pressing `⌘N` repeatedly does not stack empty `.md` files; you
  land on the single reusable blank until you actually write something.

## Architecture / Changes

| File | Change |
|------|--------|
| `Sources/NoteNestKit/Theme.swift` | Update `background` → `#262a33` and `sidebarBackground` → `#1d2027`. No other tokens change. |
| `Sources/NoteNestKit/ContentView.swift` | `newNote()` reuses an empty note (via existing `mostRecentEmptyNote()`) else creates. `confirmDelete()` sets a sensible next selection (neighbor, or create-if-empty). |
| `Sources/NoteNestKit/NotesStore.swift` | Possibly add a tiny helper to compute the post-delete neighbor id, OR keep that logic in `ContentView` using `notes` indices. Disk logic stays in `NotesStore`. |

**Boundaries preserved:** colors live only in `Theme.swift`; disk access only in
`NotesStore`; the reuse decision uses the existing `mostRecentEmptyNote()`.

## Testing

- **Unit (NotesStore / logic):**
  - `delete` then the store exposes the expected remaining notes (already
    covered); add coverage for the **post-delete neighbor** selection logic
    (whichever unit owns it gets a test: deleting a middle note selects the
    next; deleting the last selects the new last; deleting the only note
    yields an empty list so the caller creates one).
  - `⌘N` reuse decision: with an existing empty note, "new note" selects it and
    does NOT increase the note count; with no empty note, it creates one.
    (Test the underlying store/selection logic, not the SwiftUI key binding.)
- **Manual verification:**
  - Build via `scripts/build-app.sh`; confirm the editor is `#262a33` and the
    sidebar is the darker `#1d2027`, looking uniform and flush.
  - `⌘⌫` deletes the selected note after confirmation; selection lands on a
    neighbor; deleting the last note leaves a usable fresh note.
  - Press `⌘N` several times without typing → no pile of empty `.md` files in
    `~/Notes`.

## Out of Scope (YAGNI)

- Visible delete button / trash icon
- Changing text, selection, or accent colors
- Full Andromeda palette adoption beyond the two backgrounds
- Multi-select / bulk delete
- Undo-delete / trash bin
