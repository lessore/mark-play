import SwiftUI

enum BookmarkSidebarStyle {
    case sidebar
    case inspector
}

private enum SidebarPanel: String, CaseIterable, Identifiable {
    case bookmarks
    case subtitles
    case playlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookmarks:
            return "书签"
        case .subtitles:
            return "字幕"
        case .playlist:
            return "播放列表"
        }
    }
}

struct BookmarkSidebarView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel
    let style: BookmarkSidebarStyle
    @State private var selectedPanel: SidebarPanel = .bookmarks

    init(style: BookmarkSidebarStyle = .sidebar) {
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            panelContent
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Color.white.opacity(0.92))
        .background(sidebarBackground)
    }

    private var header: some View {
        HStack(spacing: 8) {
            panelPicker

            Button {
                bookmarkViewModel.finishEditingBookmark()
                NotificationCenter.default.post(name: .appCommand, object: AppCommandAction.toggleBookmarkSidebar)
            } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white.opacity(0.62))
            .help("隐藏侧栏")

            Button {
                bookmarkViewModel.finishEditingBookmark()
                if selectedPanel == .playlist {
                    NotificationCenter.default.post(name: .appCommand, object: AppCommandAction.openPlaylistFiles)
                } else {
                    bookmarkViewModel.beginBookmarkNaming(at: playerViewModel.currentTime)
                }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white.opacity(0.86))
            .help(selectedPanel == .playlist ? "添加 MP3 到播放列表" : "添加当前时间书签")
            .disabled(selectedPanel != .playlist && playerViewModel.currentRecord == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.072, green: 0.080, blue: 0.098).opacity(0.98),
                Color(red: 0.044, green: 0.050, blue: 0.064).opacity(0.99)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var headerBackground: some View {
        Color(red: 0.086, green: 0.096, blue: 0.118).opacity(0.94)
    }

    @ViewBuilder
    private var panelContent: some View {
        switch selectedPanel {
        case .bookmarks:
            if playerViewModel.currentRecord == nil {
                PlaceholderView(
                    title: "未打开媒体",
                    message: "打开本地媒体后可查看书签",
                    style: style
                )
            } else if bookmarkViewModel.sortedBookmarks.isEmpty {
                PlaceholderView(
                    title: "暂无书签",
                    message: "按 Cmd+B 添加",
                    style: style
                )
            } else {
                BookmarkListView()
            }
        case .subtitles:
            if playerViewModel.currentRecord == nil {
                PlaceholderView(
                    title: "未打开媒体",
                    message: "打开本地媒体后可查看字幕",
                    style: style,
                    systemImage: "captions.bubble"
                )
            } else if playerViewModel.subtitleCues.isEmpty {
                PlaceholderView(
                    title: "暂无内嵌字幕",
                    message: "当前媒体未检测到可用字幕",
                    style: style,
                    systemImage: "captions.bubble"
                )
            } else {
                SubtitleListView()
            }
        case .playlist:
            PlaylistView()
        }
    }

    private var panelPicker: some View {
        HStack(spacing: 6) {
            ForEach(SidebarPanel.allCases) { panel in
                Button {
                    guard selectedPanel != panel else {
                        return
                    }
                    selectedPanel = panel
                    bookmarkViewModel.finishEditingBookmark()
                } label: {
                    Text(panel.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(panelButtonForeground(for: panel))
                        .frame(minWidth: panel == .playlist ? 74 : 48)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(panelButtonBackground(for: panel))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func panelButtonForeground(for panel: SidebarPanel) -> Color {
        if selectedPanel == panel {
            return .white
        }
        return Color.white.opacity(0.82)
    }

    @ViewBuilder
    private func panelButtonBackground(for panel: SidebarPanel) -> some View {
        if selectedPanel == panel {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.accentColor)
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.clear)
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let message: String
    var style: BookmarkSidebarStyle = .sidebar
    var systemImage = "bookmark"

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(Color.white.opacity(0.34))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.56))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
