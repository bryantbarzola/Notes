import SwiftUI

public enum Theme {
    // Ghostty "Andromeda" background (#262a33)
    public static let background = Color(red: 0.149, green: 0.165, blue: 0.200)
    // Slightly darker matching shade for the sidebar (#1d2027)
    public static let sidebarBackground = Color(red: 0.114, green: 0.125, blue: 0.153)
    public static let foreground = Color(red: 0.83, green: 0.83, blue: 0.83)
    public static let secondaryText = Color(red: 0.5, green: 0.5, blue: 0.5)
    public static let accent = Color(red: 0.15, green: 0.31, blue: 0.47)
    public static let titleFontSize: CGFloat = 22
    public static let bodyFontSize: CGFloat = 14

    /// JetBrains Mono (Nerd Font variant installed locally) to match Ghostty.
    /// `Font.custom` automatically falls back to the system font if unavailable,
    /// so the app never breaks on a machine without it.
    public static let fontName = "JetBrainsMonoNL Nerd Font"

    public static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(fontName, size: size).weight(weight)
    }
}
