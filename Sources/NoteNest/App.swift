import SwiftUI
import NoteNestKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?

    func applicationWillTerminate(_ notification: Notification) {
        onTerminate?()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Returning true tells AppKit to perform its default reopen
        // (bring existing windows to the front). We intentionally do NOT
        // create a new note here — new notes are made with ⌘N.
        return true
    }
}

@main
struct NoteNestApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("showTabBar") private var showTabBar: Bool = true
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

        WindowGroup {
            ContentView(store: store, showTabBar: showTabBar)
                .preferredColorScheme(.dark)
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.saveAll()
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(.dark)
        }
    }
}
