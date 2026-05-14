import AppKit
import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开媒体...") {
                post(.openVideo)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("添加 MP3 到播放列表...") {
                post(.openPlaylistFiles)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("添加文件夹到播放列表...") {
                post(.openPlaylistFolder)
            }

            Divider()

            Button("导出书签为 CSV...") {
                post(.exportBookmarks)
            }
            .keyboardShortcut("e", modifiers: .command)
        }

        CommandMenu("播放") {
            Button("播放 / 暂停") {
                post(.togglePlayback)
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("快退 5 秒") {
                post(.skipBackward)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button("快进 5 秒") {
                post(.skipForward)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])

            Button("快退 30 秒") {
                post(.skipBackward30)
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Button("快进 30 秒") {
                post(.skipForward30)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)

            Divider()

            Button("音量增大") {
                post(.volumeUp)
            }

            Button("音量减小") {
                post(.volumeDown)
            }

            Button("静音") {
                post(.toggleMute)
            }

            Divider()

            Button("降低播放速度 0.1x") {
                post(.speedDown)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("提高播放速度 0.1x") {
                post(.speedUp)
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("恢复 1.0x") {
                post(.speedReset)
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Button("全屏") {
                post(.toggleFullscreen)
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
        }

        CommandMenu("书签") {
            Button("添加书签") {
                post(.addBookmark)
            }
            .keyboardShortcut("b", modifiers: .command)

            Divider()

            Button("显示 / 隐藏书签管理器") {
                post(.toggleBookmarkSidebar)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Divider()

            Button("删除全部书签") {
                post(.deleteAllBookmarks)
            }
        }
    }

    private func post(_ command: AppCommandAction) {
        NotificationCenter.default.post(name: .appCommand, object: command)
    }
}

enum AppCommandAction {
    case openVideo
    case openPlaylistFiles
    case openPlaylistFolder
    case exportBookmarks
    case togglePlayback
    case skipBackward
    case skipForward
    case skipBackward30
    case skipForward30
    case volumeUp
    case volumeDown
    case toggleMute
    case speedDown
    case speedUp
    case speedReset
    case toggleFullscreen
    case addBookmark
    case toggleBookmarkSidebar
    case deleteAllBookmarks
}

extension Notification.Name {
    static let appCommand = Notification.Name("appCommand")
}
