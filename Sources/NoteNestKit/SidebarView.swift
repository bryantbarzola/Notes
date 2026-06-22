import SwiftUI

public struct SidebarView: View {
    @ObservedObject private var store: NotesStore
    @Binding private var selection: String?
    private let onNew: () -> Void
    private let onDelete: (String) -> Void

    public init(
        store: NotesStore,
        selection: Binding<String?>,
        onNew: @escaping () -> Void,
        onDelete: @escaping (String) -> Void
    ) {
        self.store = store
        self._selection = selection
        self.onNew = onNew
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes")
                    .font(Theme.font(size: 11, weight: .semibold))
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Button(action: onNew) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundColor(Theme.foreground)
                .help("New note (⌘N)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(selection: $selection) {
                ForEach(store.notes) { note in
                    Text(note.title)
                        .font(Theme.font(size: Theme.bodyFontSize))
                        .lineLimit(1)
                        .foregroundColor(Theme.foreground)
                        .tag(note.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                onDelete(note.id)
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
        .background(Theme.sidebarBackground)
    }
}
