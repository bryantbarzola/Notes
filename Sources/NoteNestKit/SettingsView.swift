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
