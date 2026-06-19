import SwiftUI
import NoteNestKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }
}

@main
struct NoteNestApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = NotesStore(folder: NotesStore.defaultFolder())
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Wire up the terminate handler to flush saves
        // We'll set it after initialization in the body
    }

    var body: some Scene {
        let _ = {
            appDelegate.onTerminate = { [store] in
                MainActor.assumeIsolated {
                    store.saveAll()
                }
            }
        }()

        return WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 400, minHeight: 300)
        }
        .defaultSize(width: 900, height: 600)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.saveAll()
            }
        }
    }
}
