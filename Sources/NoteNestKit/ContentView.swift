import SwiftUI

public struct ContentView: View {
    @ObservedObject private var store: NotesStore
    @State private var selection: String?
    @State private var tabSet = TabSet()
    private let showTabBar: Bool
    private let saveDebouncer = Debouncer(interval: 0.8)

    public init(store: NotesStore, showTabBar: Bool) {
        self.store = store
        self.showTabBar = showTabBar
    }

    private var editorText: Binding<String> {
        Binding(
            get: {
                guard let id = selection,
                      let note = store.notes.first(where: { $0.id == id })
                else { return "" }
                return note.content
            },
            set: { newValue in
                guard let id = selection else { return }
                store.updateContent(of: id, to: newValue)
                saveDebouncer.call { [weak store] in
                    DispatchQueue.main.async { store?.save(id) }
                }
            }
        )
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                store: store,
                selection: $selection,
                onNew: newNote,
                onDelete: performDelete
            )
            .frame(minWidth: 180)
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
        .background(Theme.background)
        .onAppear(perform: bootstrap)
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
        // Hidden buttons provide the keyboard shortcuts.
        .background(
            Group {
                Button("", action: newNote).keyboardShortcut("n", modifiers: .command)
                Button("") { if let id = selection { performDelete(id) } }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
            .opacity(0)
        )
    }

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

    private func newNote() {
        // Reuse an existing blank note instead of stacking new empties.
        let note = store.createOrReuseEmpty()
        selection = note.id
    }

    private func performDelete(_ id: String) {
        // Deletes immediately (no confirmation) — consistent with closing a tab.
        // Compute the neighbor BEFORE deleting, so we can land on it after.
        let neighbor = store.neighborID(after: id)
        store.delete(id)
        // Drop the deleted note's tab so no orphan ("Untitled") tab remains.
        if showTabBar {
            _ = tabSet.close(id, active: nil)
        }
        if selection == id {
            if let neighbor {
                selection = neighbor
            } else {
                // No notes left — create a fresh one so the editor is never empty.
                selection = store.create().id
            }
        }
    }

    public func flushSaves() {
        store.saveAll()
    }
}
