# "Show Tab Bar" Setting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persisted "Show tab bar" setting (`⌘,`) that shows a Sublime-style tab strip above the editor; default off, sidebar always present.

**Architecture:** The open-tabs working set becomes a pure, testable `TabSet` struct. The tab strip UI moves into its own `TabBarView`. `ContentView` gains a `showTabBar: Bool` and a `TabSet`, rendering the strip only when on. A SwiftUI `Settings` scene with one `Toggle` bound to `@AppStorage("showTabBar")` provides the `⌘,` window; `App` passes the stored value into `ContentView`.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, Swift Testing. macOS 14+.

## Global Constraints

- macOS 14+, Swift 6. Repo root: `~/Documents/personal/notenest`. Build/test from there.
- Swift code under `Sources/`; tests under `SwiftTests/NoteNestKitTests`.
- Setting key: `@AppStorage("showTabBar")`, default `false`.
- Sidebar always present; the setting only shows/hides the top tab strip.
- Off = no tab strip at all + no open-tab state (the `TabSet` is empty/cleared).
- On→off clears the open tabs; off→on seeds the current selection as the first tab.
- Tab strip behavior (from the proven prototype): open in order, no duplicates, click to switch, × to close, closing the active tab activates the last remaining tab (or none), inline `+` after the last tab makes a new note via the existing reuse path.
- Disk access only in `NotesStore`; colors only in `Theme`; open-tabs logic only in `TabSet`; tab UI only in `TabBarView`.
- Safety hook BLOCKS any command containing `rm` (incl. `git rm`); stage with explicit `git add <paths>`, never `git add -A`.

---

### Task 1: `TabSet` — pure open-tabs model

**Files:**
- Create: `Sources/NoteNestKit/TabSet.swift`
- Test: `SwiftTests/NoteNestKitTests/TabSetTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public struct TabSet`:
  - `public private(set) var ids: [String]` — open tab note-ids, in open order.
  - `public init(ids: [String] = [])`
  - `public func contains(_ id: String) -> Bool`
  - `public mutating func open(_ id: String)` — append if not already present (no duplicates); no-op if present.
  - `public mutating func close(_ id: String, active: String?) -> String?` — remove `id`; if `id` was the `active` one, return the new id to activate (the last remaining id, or `nil` if none); if `id` was not active (or not present), return `active` unchanged.
  - `public mutating func clear()` — empty the set.

- [ ] **Step 1: Write the failing tests**

`SwiftTests/NoteNestKitTests/TabSetTests.swift`:
```swift
import Testing
@testable import NoteNestKit

@Test func openAppendsInOrder() {
    var t = TabSet()
    t.open("a"); t.open("b"); t.open("c")
    #expect(t.ids == ["a", "b", "c"])
}

@Test func openIsIdempotentNoDuplicates() {
    var t = TabSet()
    t.open("a"); t.open("a")
    #expect(t.ids == ["a"])
    #expect(t.contains("a"))
}

@Test func closeActiveActivatesLastRemaining() {
    var t = TabSet(ids: ["a", "b", "c"])
    // closing the active "b" → last remaining is "c"
    let next = t.close("b", active: "b")
    #expect(t.ids == ["a", "c"])
    #expect(next == "c")
}

@Test func closeActiveWhenLastRemovedActivatesNewLast() {
    var t = TabSet(ids: ["a", "b"])
    let next = t.close("b", active: "b")
    #expect(t.ids == ["a"])
    #expect(next == "a")
}

@Test func closeOnlyTabReturnsNil() {
    var t = TabSet(ids: ["a"])
    let next = t.close("a", active: "a")
    #expect(t.ids.isEmpty)
    #expect(next == nil)
}

@Test func closeNonActiveLeavesActiveUnchanged() {
    var t = TabSet(ids: ["a", "b", "c"])
    let next = t.close("a", active: "c")
    #expect(t.ids == ["b", "c"])
    #expect(next == "c")
}

@Test func clearEmptiesTheSet() {
    var t = TabSet(ids: ["a", "b"])
    t.clear()
    #expect(t.ids.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/Documents/personal/notenest && swift test --filter TabSet`
Expected: FAIL — cannot find `TabSet` in scope.

- [ ] **Step 3: Write the implementation**

`Sources/NoteNestKit/TabSet.swift`:
```swift
/// Pure, UI-agnostic model of the open-tabs "working set" (Sublime-style).
/// Order is open order; ids are note ids. No SwiftUI here.
public struct TabSet {
    public private(set) var ids: [String]

    public init(ids: [String] = []) {
        self.ids = ids
    }

    public func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    public mutating func open(_ id: String) {
        guard !ids.contains(id) else { return }
        ids.append(id)
    }

    /// Removes `id`. If `id` was the active tab, returns the id to activate next
    /// (the last remaining tab, or nil if none). Otherwise returns `active`
    /// unchanged.
    public mutating func close(_ id: String, active: String?) -> String? {
        ids.removeAll { $0 == id }
        if active == id {
            return ids.last
        }
        return active
    }

    public mutating func clear() {
        ids.removeAll()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/Documents/personal/notenest && swift test --filter TabSet`
Expected: PASS (7 tests).

- [ ] **Step 5: Run the full suite**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 30 tests pass (23 prior + 7 new).

- [ ] **Step 6: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/TabSet.swift SwiftTests/NoteNestKitTests/TabSetTests.swift
git commit -m "feat: add pure TabSet model for open-tabs working set"
```

---

### Task 2: `TabBarView` — the tab strip UI

**Files:**
- Create: `Sources/NoteNestKit/TabBarView.swift`

**Interfaces:**
- Consumes: `Theme`. Receives data + callbacks (does not own state).
- Produces: `public struct TabBarView: View`:
  - `init(tabIDs: [String], activeID: String?, title: @escaping (String) -> String, onSelect: @escaping (String) -> Void, onClose: @escaping (String) -> Void, onNew: @escaping () -> Void)`
  - Renders a horizontal strip: one cell per `tabIDs` (title + × close), active cell highlighted (accent top-border, editor-color bg; inactive use sidebar color), then an inline `+` after the last tab.

**Note:** Pure SwiftUI view, no unit test; verified by build + Task 5 manual check.

- [ ] **Step 1: Create the view**

`Sources/NoteNestKit/TabBarView.swift`:
```swift
import SwiftUI

public struct TabBarView: View {
    private let tabIDs: [String]
    private let activeID: String?
    private let title: (String) -> String
    private let onSelect: (String) -> Void
    private let onClose: (String) -> Void
    private let onNew: () -> Void

    public init(
        tabIDs: [String],
        activeID: String?,
        title: @escaping (String) -> String,
        onSelect: @escaping (String) -> Void,
        onClose: @escaping (String) -> Void,
        onNew: @escaping () -> Void
    ) {
        self.tabIDs = tabIDs
        self.activeID = activeID
        self.title = title
        self.onSelect = onSelect
        self.onClose = onClose
        self.onNew = onNew
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(tabIDs, id: \.self) { id in
                    let isActive = id == activeID
                    HStack(spacing: 6) {
                        Text(title(id))
                            .lineLimit(1)
                            .font(.system(size: 12))
                            .foregroundColor(isActive ? Theme.foreground : Theme.secondaryText)
                        Button {
                            onClose(id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Theme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isActive ? Theme.background : Theme.sidebarBackground)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(isActive ? Theme.accent : .clear)
                            .frame(height: 2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(id) }
                }
                Button(action: onNew) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New note (⌘N)")
                Spacer(minLength: 0)
            }
        }
        .frame(height: 32)
        .background(Theme.sidebarBackground)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd ~/Documents/personal/notenest && swift build`
Expected: Build complete.

- [ ] **Step 3: Run the full suite (no regressions)**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 30 tests pass.

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/TabBarView.swift
git commit -m "feat: add TabBarView tab strip UI"
```

---

### Task 3: `SettingsView` — the toggle

**Files:**
- Create: `Sources/NoteNestKit/SettingsView.swift`

**Interfaces:**
- Consumes: nothing (binds its own `@AppStorage`).
- Produces: `public struct SettingsView: View` with `public init()`; one `Toggle("Show tab bar", isOn:)` bound to `@AppStorage("showTabBar")` (default false), padded in a `Form`.

**Note:** Pure SwiftUI view, no unit test; verified by build + manual check.

- [ ] **Step 1: Create the view**

`Sources/NoteNestKit/SettingsView.swift`:
```swift
import SwiftUI

public struct SettingsView: View {
    @AppStorage("showTabBar") private var showTabBar: Bool = false

    public init() {}

    public var body: some View {
        Form {
            Toggle("Show tab bar", isOn: $showTabBar)
        }
        .padding(20)
        .frame(width: 320)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd ~/Documents/personal/notenest && swift build`
Expected: Build complete.

- [ ] **Step 3: Run the full suite (no regressions)**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 30 tests pass.

- [ ] **Step 4: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/SettingsView.swift
git commit -m "feat: add SettingsView with Show tab bar toggle"
```

---

### Task 4: Wire `showTabBar` + `TabSet` into `ContentView` and `App`

**Files:**
- Modify: `Sources/NoteNestKit/ContentView.swift`
- Modify: `Sources/NoteNest/App.swift`

**Interfaces:**
- Consumes: `TabSet` (Task 1), `TabBarView` (Task 2), `SettingsView` (Task 3); existing `NotesStore`, `Theme`, `selection`, `newNote()`.
- Produces: `ContentView(store:showTabBar:)`; tab strip shown when `showTabBar`.

- [ ] **Step 1: Update `ContentView` to accept `showTabBar` and hold a `TabSet`**

In `Sources/NoteNestKit/ContentView.swift`, change the stored properties and init. Replace:
```swift
public struct ContentView: View {
    @ObservedObject private var store: NotesStore
    @State private var selection: String?
    @State private var pendingDeleteID: String?
    @State private var showDeleteConfirm = false
    private let saveDebouncer = Debouncer(interval: 0.8)

    public init(store: NotesStore) {
        self.store = store
    }
```
with:
```swift
public struct ContentView: View {
    @ObservedObject private var store: NotesStore
    @State private var selection: String?
    @State private var pendingDeleteID: String?
    @State private var showDeleteConfirm = false
    @State private var tabSet = TabSet()
    private let showTabBar: Bool
    private let saveDebouncer = Debouncer(interval: 0.8)

    public init(store: NotesStore, showTabBar: Bool) {
        self.store = store
        self.showTabBar = showTabBar
    }
```

- [ ] **Step 2: Render the tab strip when enabled, and keep `TabSet` in sync**

In `ContentView`'s `body`, replace the `detail:` closure:
```swift
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
```
with:
```swift
        } detail: {
            VStack(spacing: 0) {
                if showTabBar {
                    TabBarView(
                        tabIDs: tabSet.ids,
                        activeID: selection,
                        title: { id in store.notes.first(where: { $0.id == id })?.title ?? "Untitled" },
                        onSelect: { selection = $0 },
                        onClose: { id in selection = tabSet.close(id, active: selection) },
                        onNew: newNote
                    )
                }
                if selection != nil {
                    EditorView(text: editorText)
                } else {
                    Text("No note selected")
                        .foregroundColor(Theme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.background)
                }
            }
        }
```

- [ ] **Step 3: Add the selection→TabSet sync + toggle-seeding modifiers**

In `ContentView`'s `body`, immediately after the existing `.onAppear(perform: bootstrap)` line, add BOTH modifiers:
```swift
        .onChange(of: selection) { _, newValue in
            // Keep the tab set in sync only when the tab bar is enabled.
            guard showTabBar else { return }
            if let id = newValue { tabSet.open(id) }
        }
        .onChange(of: showTabBar) { _, isOn in
            if isOn {
                // Off→on: seed the currently selected note as the first tab,
                // even if selection doesn't subsequently change.
                if let id = selection { tabSet.open(id) }
            } else {
                // On→off: drop all open-tab state (no hidden state).
                tabSet.clear()
            }
        }
```

- [ ] **Step 4: Seed the tab set on appear when tabs are enabled**

In `ContentView`'s `bootstrap()`, add a final line at the very end of the method (after the existing selection assignment / early returns are resolved) so the currently selected note becomes the first tab when the bar is on. Replace:
```swift
    private func bootstrap() {
        store.ensureFolderExists()
        store.reload()
        if store.notes.isEmpty {
            store.create()
        } else if let empty = store.mostRecentEmptyNote() {
            // Reuse an existing blank note instead of creating another,
            // so launching repeatedly doesn't litter ~/Notes with empties.
            selection = empty.id
            return
        } else {
            store.create()
        }
        selection = store.notes.first?.id
    }
```
with:
```swift
    private func bootstrap() {
        store.ensureFolderExists()
        store.reload()
        if store.notes.isEmpty {
            store.create()
        } else if let empty = store.mostRecentEmptyNote() {
            // Reuse an existing blank note instead of creating another,
            // so launching repeatedly doesn't litter ~/Notes with empties.
            selection = empty.id
            return
        } else {
            store.create()
        }
        selection = store.notes.first?.id
    }
```
(No change needed inside `bootstrap()` itself — the `.onChange(of: selection)` modifier from Step 3 fires when `bootstrap` sets `selection`, seeding the first tab. The early-return reuse branch also sets `selection`, which likewise triggers the sync. This step is a verification checkpoint: confirm both selection-assignment paths trigger the onChange.)

- [ ] **Step 5: Add the `Settings` scene and pass `showTabBar` from `App`**

In `Sources/NoteNest/App.swift`, add `@AppStorage("showTabBar")` and pass it into `ContentView`, and add a `Settings` scene. Replace:
```swift
@main
struct NoteNestApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = NotesStore(folder: NotesStore.defaultFolder())
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Wire up the terminate handler to flush saves
        // We'll set it after initialization in the body
    }

    var body: some Scene {
        let _ = {
            appDelegate.onTerminate = { [store] in
                MainActor.assumeIsolated {
                    store.saveAll()
                }
            }
        }()

        return WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.saveAll()
            }
        }
    }
}
```
with:
```swift
@main
struct NoteNestApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("showTabBar") private var showTabBar: Bool = false
    @StateObject private var store = NotesStore(folder: NotesStore.defaultFolder())
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Wire up the terminate handler to flush saves
        // We'll set it after initialization in the body
    }

    var body: some Scene {
        let _ = {
            appDelegate.onTerminate = { [store] in
                MainActor.assumeIsolated {
                    store.saveAll()
                }
            }
        }()

        return WindowGroup {
            ContentView(store: store, showTabBar: showTabBar)
                .preferredColorScheme(.dark)
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.saveAll()
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 6: Build to verify it compiles**

Run: `cd ~/Documents/personal/notenest && swift build`
Expected: Build complete (no errors).

- [ ] **Step 7: Run the full suite**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 30 tests pass.

- [ ] **Step 8: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/ContentView.swift Sources/NoteNest/App.swift
git commit -m "feat: wire Show tab bar setting into ContentView and add Settings scene"
```

---

### Task 5: Manual verification (DEFER TO HUMAN)

**Files:** none.

Needs a real GUI; cannot be done headlessly.

- [ ] **Step 1: Build and run**

The human runs:
```bash
cd ~/Documents/personal/notenest && ./scripts/build-app.sh
```

- [ ] **Step 2: Default-off check**
- On first launch (or with the setting never touched), there is NO tab strip — the app looks exactly like the shipped sidebar+editor.

- [ ] **Step 3: Settings toggle**
- Press `⌘,` → a Settings window opens with a "Show tab bar" checkbox.
- Turn it ON → the tab strip appears above the editor; the current note is its first tab.
- Turn it OFF → the tab strip disappears; editor still shows the selected note.
- Quit and relaunch → the last setting is remembered.

- [ ] **Step 4: Tabs behavior (with setting ON)**
- Clicking sidebar notes accumulates tabs; clicking a tab switches; × closes (closing the active tab falls back to the last remaining); inline `+` makes a new note.

- [ ] **Step 5: Confirm to the controller**
- Report pass/fail per check; screenshot if convenient.

---

## Self-Review Notes

- **Spec coverage:**
  - Persisted `@AppStorage("showTabBar")` default false (T3 SettingsView + T4 App).
  - Settings window `⌘,` with one toggle (T3 + T4 `Settings` scene).
  - Sidebar always present; tab strip only when on (T4 conditional render).
  - Off = no strip + empty tab state (T4: `TabSet` only synced when `showTabBar`; never populated when off).
  - On seeds current selection as first tab (T4 Step 3 onChange fires on bootstrap's selection set).
  - Tab behaviors: open/dedup/switch/close-active-fallback/`+` (T1 TabSet logic + T2 TabBarView UI + T4 wiring).
  - Boundaries: open-tabs logic in `TabSet`, UI in `TabBarView`, colors in `Theme`, disk in `NotesStore` (unchanged).
  - Manual checks for default-off, settings persistence, tab behaviors (T5).
- **Placeholder scan:** No TBD/TODO; every code step has complete code. T5 is an explicit human GUI check, consistent with prior tasks. T4 Step 4 is a verification checkpoint (no code change) — explicitly labeled as such, not a placeholder.
- **Type consistency:** `TabSet.open(_:)`, `close(_:active:) -> String?`, `clear()`, `ids`, `contains(_:)` defined T1, used T4. `TabBarView(tabIDs:activeID:title:onSelect:onClose:onNew:)` defined T2, used T4. `ContentView(store:showTabBar:)` defined T4, used by App T4 Step 5. `@AppStorage("showTabBar")` key identical in T3 and T4.
- **Off→on / on→off transitions:** handled explicitly by the `.onChange(of: showTabBar)` modifier (T4 Step 3): turning it on immediately seeds the current `selection` as the first tab (no dependence on a later selection change); turning it off calls `tabSet.clear()` so no hidden state remains. This satisfies the spec's transition requirements directly.
- **Test count:** prior = 23; T1 adds 7 → 30 through T4. Verified prior count (23) from the last `swift test`.
- **Hook caveat:** `rm` ban noted; all staging uses explicit `git add`.
