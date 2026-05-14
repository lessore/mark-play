import AppKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct MarkPlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var bookmarkViewModel = BookmarkViewModel()
    @StateObject private var playlistViewModel = PlaylistViewModel()
    private let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: VideoRecord.self, Bookmark.self)
        } catch {
            fatalError("ModelContainer 初始化失败：\(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerViewModel)
                .environmentObject(bookmarkViewModel)
                .environmentObject(playlistViewModel)
                .modelContainer(sharedModelContainer)
                .frame(minWidth: 760, minHeight: 460)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppCommands()
        }
    }
}
