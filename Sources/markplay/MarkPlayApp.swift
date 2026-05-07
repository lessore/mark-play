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
}

@main
struct MarkPlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var bookmarkViewModel = BookmarkViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerViewModel)
                .environmentObject(bookmarkViewModel)
                .modelContainer(for: [VideoRecord.self, Bookmark.self])
                .frame(minWidth: 760, minHeight: 460)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppCommands()
        }
    }
}
