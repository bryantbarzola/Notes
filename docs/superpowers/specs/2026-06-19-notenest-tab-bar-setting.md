# NoteNest — "Show Tab Bar" Setting

**Date:** 2026-06-19
**Status:** Approved design, ready for implementation plan
**Builds on:** the shipped Swift app (sidebar-only) + a throwaway tabs prototype
(`experiment/top-tabs` worktree) that proved the tab UI.

## Purpose

Let the user optionally show a Sublime-style tab strip above the editor, via a
persisted Settings checkbox. The sidebar always remains; tabs are an optional
layer on top. Default off, so the shipped experience is unchanged until the
user opts in.

## Decisions (from brainstorming)

- **Build fresh off `main`** in a new branch; the prototype is a proven
  reference, not the basis (it was scrappy and untested). The tab-bar code is
  lifted over and cleaned up + tested.
- **Toggle, not a 3-way mode.** Sidebar is always present; the setting turns the
  top tab strip on/off.
- **Off means off:** when the setting is off, there is no tab strip at all
  (identical to today's shipped app) and no hidden open-tab state.
- **Control lives in a Settings window** (`⌘,`), one checkbox "Show tab bar".
- **Default OFF.** First launch looks exactly like the shipped app.
- **Persisted** between launches via `@AppStorage("showTabBar")`.
- Tab strip behavior (from the prototype, retained): opening/selecting a note
  adds it as a tab; tabs accumulate in open order; click a tab to switch; each
  tab has an × to close; closing the active tab falls back to the last
  remaining open tab; an inline `+` after the last tab makes a new note
  (reusing an empty note, consistent with `⌘N`).

## Behavior

### Setting
- Settings window (`⌘,`) shows a single `Toggle`: **"Show tab bar"**.
- Backed by `@AppStorage("showTabBar")`, default `false`.
- Changing it updates the main window live (no relaunch needed) and persists.

### Tabs OFF (default)
- No tab strip. Sidebar + editor exactly as shipped.
- No open-tab tracking occurs.

### Tabs ON
- A tab strip renders above the editor (below the unified title bar).
- Selecting a note in the sidebar opens/focuses its tab; tabs accumulate.
- Click a tab → switch to that note. Click its × → close it; if it was active,
  selection falls back to the last remaining open tab (or none if empty).
- Inline `+` after the last tab → new note (via the existing reuse logic).
- The active tab is visually distinguished (accent top-border, editor-color
  background); inactive tabs use the sidebar color.

### Toggling at runtime
- OFF→ON: the tab strip appears; the currently selected note becomes the first
  open tab.
- ON→OFF: the tab strip disappears; `openTabs` is cleared (no hidden state).
  The selected note remains shown in the editor.

## Architecture / Changes

| File | Change |
|------|--------|
| `Sources/NoteNestKit/TabSet.swift` (new) | Pure, testable model of the open-tabs working set: ordered ids, `open(id)` (append if absent), `close(id) -> String?` (remove; return the id to activate if the closed one was active), `contains`, `ids`. No SwiftUI. |
| `Sources/NoteNestKit/TabBarView.swift` (new) | SwiftUI tab strip view (tabs + inline `+`), driven by `TabSet` ids, the active selection, and callbacks (`onSelect`, `onClose`, `onNew`). Uses `Theme`. |
| `Sources/NoteNestKit/ContentView.swift` | Accept `showTabBar: Bool`. Hold a `TabSet` in `@State`. When `showTabBar`, render `TabBarView` above the editor and keep the `TabSet` in sync with `selection`; when off, keep the strip absent and the `TabSet` empty. |
| `Sources/NoteNestKit/SettingsView.swift` (new) | `Toggle("Show tab bar", isOn: $showTabBar)` bound to `@AppStorage("showTabBar")`. |
| `Sources/NoteNest/App.swift` | Add a `Settings { SettingsView() }` scene (provides `⌘,`). Read `@AppStorage("showTabBar")` and pass into `ContentView(store:showTabBar:)`. |

**Boundaries preserved:** disk access stays in `NotesStore`; colors stay in
`Theme`; the open-tabs logic is isolated in the testable `TabSet`; the tab
strip UI is isolated in `TabBarView` so `ContentView` stays focused.

### Data flow
`@AppStorage("showTabBar")` (in `App`) → `ContentView(showTabBar:)`. Selecting a
note sets `selection` (existing). When `showTabBar` is on, `selection` changes
also `tabSet.open(id)`; `TabBarView` renders `tabSet.ids` with `selection` as
active; closing calls `tabSet.close(id)` and updates `selection` from its
return. When `showTabBar` flips off, `tabSet` is cleared.

## Testing

- **Unit (`TabSet`):**
  - `open(id)` appends a new id; opening an already-open id does not duplicate.
  - `close(id)` removes it; closing the **active** id returns the new id to
    activate (the last remaining open tab), or `nil` when none remain.
  - `close` of a non-active id leaves the active selection unchanged (returns
    nil / no activation change).
  - order is preserved (open order).
- **Manual verification:**
  - Default launch: no tab strip (matches shipped app).
  - `⌘,` opens Settings; toggling "Show tab bar" on makes the strip appear and
    off makes it disappear; the choice survives quitting and relaunching.
  - With tabs on: clicking sidebar notes accumulates tabs; switching, closing
    (× and active-fallback), and the inline `+` all work.

## Out of Scope (YAGNI)

- Tabs-only mode (removing the sidebar) — sidebar always stays.
- Drag-to-reorder tabs; tab overflow/scroll menus beyond basic horizontal scroll.
- Persisting the *set of open tabs* between launches (only the on/off setting
  persists).
- Per-window tab sets / multiple windows.
- Any other settings beyond the single "Show tab bar" toggle.
