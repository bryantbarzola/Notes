# Dock Icon + Launch-to-Fresh-Note Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give NoteNest a distinct Dock icon and make launching it land on a ready-to-write note (reusing an empty note so `~/Notes` never fills with blanks), while a Dock click on the already-running app just brings the window forward.

**Architecture:** Three small, independent pieces. (1) A pure logic addition to `NotesStore` — `mostRecentEmptyNote()` — unit-tested. (2) A `bootstrap()` change in `ContentView` to reuse-or-create on launch, plus an `applicationShouldHandleReopen` in the app delegate so re-activation doesn't spawn notes. (3) A committed CoreGraphics icon-generator script + `build-app.sh` wiring to ship an `AppIcon.icns` in the bundle.

**Tech Stack:** Swift 6, SwiftUI, AppKit (icon render + app delegate), Swift Package Manager, Swift Testing. `iconutil` + `sips` for `.icns` assembly. macOS 14+.

## Global Constraints

- macOS 14+, Swift 6. Repo root: `~/Documents/personal/notenest`. Build/test from there.
- Swift code under `Sources/`; tests under `SwiftTests/NoteNestKitTests`.
- ALL filesystem access stays in `NotesStore`. Empty-note detection is pure logic on `Note.content`, lives in `NotesStore`.
- "Empty" note = `content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`.
- Notes are kept newest-first (by file modification date) after `reload()`.
- Dock-click behavior "B": launching opens a ready note; already-running click only brings window forward (no new note). `⌘N` still makes new notes.
- Icon is generated (no external design dep), swappable later, bundled as `AppIcon.icns` with `CFBundleIconFile` = `AppIcon`.
- Safety hook BLOCKS any shell command containing the token `rm` (including `git rm`). Never use `rm`; stage with explicit `git add <paths>`, never `git add -A`.

---

### Task 1: `NotesStore.mostRecentEmptyNote()`

**Files:**
- Modify: `Sources/NoteNestKit/NotesStore.swift` (add one method)
- Test: `SwiftTests/NoteNestKitTests/NotesStoreTests.swift` (add tests)

**Interfaces:**
- Consumes: existing `Note` (has `content`, `id`), `NotesStore.notes` (newest-first), `create`, `updateContent`.
- Produces: `public func mostRecentEmptyNote() -> Note?` — returns the first note in `notes` (which is newest-first) whose `content` is empty or whitespace-only; `nil` if none.

- [ ] **Step 1: Write the failing tests**

Append to `SwiftTests/NoteNestKitTests/NotesStoreTests.swift`:
```swift
@MainActor
@Test func mostRecentEmptyReturnsNilWhenAllHaveContent() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create()
    store.updateContent(of: a.id, to: "has content")
    #expect(store.mostRecentEmptyNote() == nil)
}

@MainActor
@Test func mostRecentEmptyReturnsAnEmptyNote() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create()  // empty by default
    #expect(store.mostRecentEmptyNote()?.id == a.id)
}

@MainActor
@Test func mostRecentEmptyTreatsWhitespaceAsEmpty() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    let a = store.create()
    store.updateContent(of: a.id, to: "   \n\t  ")
    #expect(store.mostRecentEmptyNote()?.id == a.id)
}

@MainActor
@Test func mostRecentEmptyPicksNewestEmptyAmongMixed() {
    let folder = tempFolder()
    let store = NotesStore(folder: folder)
    store.ensureFolderExists()
    // create() inserts at front, so the LAST created is newest (index 0).
    let older = store.create()
    store.updateContent(of: older.id, to: "content")
    let newerEmpty = store.create()  // empty, now at front
    #expect(store.mostRecentEmptyNote()?.id == newerEmpty.id)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/Documents/personal/notenest && swift test --filter mostRecentEmpty`
Expected: FAIL — `value of type 'NotesStore' has no member 'mostRecentEmptyNote'`.

- [ ] **Step 3: Add the implementation**

In `Sources/NoteNestKit/NotesStore.swift`, add this method inside the `NotesStore` class (e.g. right after `delete(_:)`):
```swift
    public func mostRecentEmptyNote() -> Note? {
        notes.first { $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/Documents/personal/notenest && swift test --filter mostRecentEmpty`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full suite (no regressions)**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 18 tests pass (14 prior + 4 new).

- [ ] **Step 6: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/NotesStore.swift SwiftTests/NoteNestKitTests/NotesStoreTests.swift
git commit -m "feat: add NotesStore.mostRecentEmptyNote for launch reuse"
```

---

### Task 2: Launch reuse + Dock-reopen behavior

**Files:**
- Modify: `Sources/NoteNestKit/ContentView.swift` (`bootstrap()`)
- Modify: `Sources/NoteNest/App.swift` (app delegate reopen handler)

**Interfaces:**
- Consumes: `NotesStore.mostRecentEmptyNote()` (Task 1), existing `ensureFolderExists`, `reload`, `create`, `notes`.
- Produces: launch lands on a reused empty note when available; Dock-reopen brings window forward without creating notes. No new public API.

- [ ] **Step 1: Update `bootstrap()` to reuse an empty note**

In `Sources/NoteNestKit/ContentView.swift`, replace the current `bootstrap()`:
```swift
    private func bootstrap() {
        store.ensureFolderExists()
        store.reload()
        if store.notes.isEmpty {
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

- [ ] **Step 2: Add the reopen handler to the app delegate**

In `Sources/NoteNest/App.swift`, add this method to the existing `AppDelegate` class (which already has `onTerminate` / `applicationWillTerminate`):
```swift
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Returning true tells AppKit to perform its default reopen
        // (bring existing windows to the front). We intentionally do NOT
        // create a new note here — new notes are made with ⌘N.
        return true
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd ~/Documents/personal/notenest && swift build`
Expected: Build complete (no errors).

- [ ] **Step 4: Run the full suite (no regressions)**

Run: `cd ~/Documents/personal/notenest && swift test`
Expected: 18 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/personal/notenest
git add Sources/NoteNestKit/ContentView.swift Sources/NoteNest/App.swift
git commit -m "feat: launch reuses an empty note; dock reopen just brings window forward"
```

---

### Task 3: Generate and bundle the Dock icon

**Files:**
- Create: `scripts/make-icon.swift`
- Modify: `scripts/build-app.sh`

**Interfaces:**
- Consumes: nothing in Swift package code (build-time only).
- Produces: `AppIcon.icns` built from the generator; bundled into `NoteNest.app/Contents/Resources/` with `Info.plist` `CFBundleIconFile` = `AppIcon`.

**Note:** This task's deliverable is verified at build time (the script runs and the icon appears in the bundle). The final Dock-appearance check is part of the Task 4 manual smoke test.

- [ ] **Step 1: Create the icon generator script**

`scripts/make-icon.swift`:
```swift
#!/usr/bin/env swift
// Renders the NoteNest app icon to a 1024x1024 PNG using AppKit/CoreGraphics.
// Usage: swift scripts/make-icon.swift <output-png-path>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let size = 512  // logical points; NSImage renders at 2x → 1024 px

let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Dark rounded-square background.
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let bg = CGPath(roundedRect: rect.insetBy(dx: 24, dy: 24),
                cornerWidth: 96, cornerHeight: 96, transform: nil)
ctx.addPath(bg)
ctx.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1))
ctx.fillPath()

// Three "note line" strokes (the last one shorter) in a soft blue.
ctx.setStrokeColor(CGColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 1))
ctx.setLineWidth(22)
ctx.setLineCap(.round)
let ys = [332, 256, 180]            // top to bottom
for (i, y) in ys.enumerated() {
    let endX = (i == 2) ? size - 230 : size - 170
    ctx.move(to: CGPoint(x: 170, y: y))
    ctx.addLine(to: CGPoint(x: endX, y: y))
    ctx.strokePath()
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
```

- [ ] **Step 2: Verify the generator runs**

Run:
```bash
cd ~/Documents/personal/notenest && swift scripts/make-icon.swift /tmp/notenest-icon-check.png && sips -g pixelWidth /tmp/notenest-icon-check.png | tail -1
```
Expected: prints `wrote /tmp/notenest-icon-check.png` and `pixelWidth: 1024`.

- [ ] **Step 3: Wire icon build into `build-app.sh`**

Edit `scripts/build-app.sh`. After the `swift build -c release` line and `BIN_PATH`/`APP` setup, and BEFORE the `cat > "$APP/Contents/Info.plist"` heredoc, insert an icon-build block:
```bash
# --- Build the app icon (AppIcon.icns) ---
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
BASE_PNG="$(mktemp -d)/icon-1024.png"
swift scripts/make-icon.swift "$BASE_PNG"
# Generate the required iconset sizes from the 1024 master.
for SZ in 16 32 64 128 256 512 1024; do
  sips -z "$SZ" "$SZ" "$BASE_PNG" --out "$ICONSET/icon_${SZ}x${SZ}.png" >/dev/null
done
# Retina (@2x) variants expected by iconutil.
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
mkdir -p "$APP/Contents/Resources"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
```
Then add the icon key to the `Info.plist` heredoc — insert this line inside the `<dict>` (e.g. right after the `CFBundleName` line):
```
  <key>CFBundleIconFile</key><string>AppIcon</string>
```

- [ ] **Step 4: Run the build script and verify the icon is bundled**

Run:
```bash
cd ~/Documents/personal/notenest && ./scripts/build-app.sh && ls -la NoteNest.app/Contents/Resources/AppIcon.icns && /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" NoteNest.app/Contents/Info.plist
```
Expected: the app builds and opens; `AppIcon.icns` exists in Resources; the plist prints `AppIcon`.
(Note: the build script runs `open "$APP"` at the end — a window will appear. That's fine; it's also the start of the Task 4 manual check.)

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/personal/notenest
git add scripts/make-icon.swift scripts/build-app.sh
git commit -m "feat: generate and bundle a Dock app icon"
```

---

### Task 4: Manual verification (DEFER TO HUMAN)

**Files:** none (verification only).

This step needs a real GUI/Dock and CANNOT be done headlessly.

- [ ] **Step 1: Build and run**

The human runs:
```bash
cd ~/Documents/personal/notenest && ./scripts/build-app.sh
```

- [ ] **Step 2: Verify the Dock icon**
- The Dock shows NoteNest's new icon (dark rounded square with the note-line mark), not the generic blank icon.
  - (If macOS shows a stale icon from a prior run, it's an icon-cache quirk; quitting the app and re-running the script, or moving the `.app`, refreshes it.)

- [ ] **Step 3: Verify launch-to-fresh-note + no clutter**
- Note the current files: `ls ~/Notes`.
- Quit NoteNest, relaunch via the script WITHOUT typing anything, quit again, relaunch again.
- `ls ~/Notes` again: the count of empty notes did NOT grow each launch (the empty note is reused). At most one trailing empty note exists.
- Type into the note, then relaunch: a fresh/ready note is presented (the now-non-empty note was not reused).

- [ ] **Step 4: Verify Dock-reopen does not spawn notes**
- With NoteNest already open, click its Dock icon: the existing window comes to the front and NO new note is created.
- `⌘N` still creates a new note.

- [ ] **Step 5: Confirm to the controller**
- Report whether all checks passed. If anything fails, capture which step and (if visual) a screenshot, before proceeding to finish the branch.

---

## Self-Review Notes

- **Spec coverage:**
  - Distinct Dock icon, generated, swappable, bundled with `CFBundleIconFile` (T3).
  - Launch lands on ready note; reuse most-recent empty else create (T1 logic + T2 bootstrap).
  - Dock-click while running → window forward, no new note (`applicationShouldHandleReopen`, T2).
  - `⌘N` unchanged (not modified).
  - Empty = whitespace-only (T1 constraint + test `mostRecentEmptyTreatsWhitespaceAsEmpty`).
  - Empty-note detection is pure logic in `NotesStore` (T1); views only call it (T2).
  - Manual checks for Dock appearance + no-clutter + reopen (T4).
- **Placeholder scan:** No TBD/TODO. Every code step has complete code. T4 is an explicit human GUI/Dock check (cannot be headless), consistent with prior tasks.
- **Type consistency:** `mostRecentEmptyNote() -> Note?` defined in T1, consumed in T2's `bootstrap()`. `Note.content`/`.id`, `store.notes`/`create`/`reload`/`ensureFolderExists` match the current code (verified against the files). `AppDelegate` already exists in `App.swift`; T2 adds one method to it.
- **Test count:** prior suite = 14; T1 adds 4 → 18 through T2/T3 (T3 adds no Swift tests). Verified the prior count from `swift test` (14).
- **Hook caveat:** `rm` ban noted in Global Constraints; all staging uses explicit `git add`. The icon script uses `mktemp -d` scratch dirs (no `rm` needed; OS cleans temp).
