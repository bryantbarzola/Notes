import SwiftUI
import NoteNestKit

@main
struct NoteNestApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 400, minHeight: 300)
        }
        .defaultSize(width: 900, height: 600)
    }
}
