import SwiftUI

public struct EditorView: View {
    @Binding private var text: String

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        TextEditor(text: $text)
            .font(Theme.font(size: Theme.bodyFontSize))
            .foregroundColor(Theme.foreground)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
    }
}
