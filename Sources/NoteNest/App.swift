import SwiftUI

@main
struct NoteNestApp: App {
    var body: some Scene {
        WindowGroup {
            Text("NoteNest")
                .frame(minWidth: 400, minHeight: 300)
        }
        .defaultSize(width: 900, height: 600)
    }
}
