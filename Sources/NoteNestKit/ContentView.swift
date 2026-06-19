import SwiftUI

public struct ContentView: View {
    @ObservedObject private var store: NotesStore
    @State private var selection: String?
    @State private var pendingDeleteID: String?
    @State private var showDeleteConfirm = false
    private let saveDebouncer = Debouncer(interval: 0.8)

    public init(store: NotesStore) {
        self.store = store
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
                onDelete: requestDelete
            )
            .frame(minWidth: 180)
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
        .background(Theme.background)
        .onAppear(perform: bootstrap)
        .confirmationDialog(
            "Delete this note?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDelete)
            Button("Cancel", role: .cancel) {}
        }
        // Hidden buttons provide the keyboard shortcuts.
        .background(
            Group {
                Button("", action: newNote).keyboardShortcut("n", modifiers: .command)
                Button("") { if let id = selection { requestDelete(id) } }
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
        }
        selection = store.notes.first?.id
    }

    private func newNote() {
        let note = store.create()
        selection = note.id
    }

    private func requestDelete(_ id: String) {
        pendingDeleteID = id
        showDeleteConfirm = true
    }

    private func confirmDelete() {
        guard let id = pendingDeleteID else { return }
        store.delete(id)
        if selection == id {
            selection = store.notes.first?.id
        }
        pendingDeleteID = nil
    }

    public func flushSaves() {
        store.saveAll()
    }
}
