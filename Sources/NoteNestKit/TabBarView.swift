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
