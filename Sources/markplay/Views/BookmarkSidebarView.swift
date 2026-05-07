import SwiftUI

enum BookmarkSidebarStyle {
    case sidebar
    case inspector
}

struct BookmarkSidebarView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel
    let style: BookmarkSidebarStyle

    init(style: BookmarkSidebarStyle = .sidebar) {
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            if playerViewModel.currentRecord == nil {
                PlaceholderView(
                    title: "未打开视频",
                    message: "打开本地视频后可添加书签",
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
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(foregroundColor)
        .background(backgroundStyle)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("书签管理器")
                    .font(.headline)
                if let fileName = playerViewModel.currentRecord?.fileName {
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(secondaryForegroundColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                NotificationCenter.default.post(name: .appCommand, object: AppCommandAction.toggleBookmarkSidebar)
            } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(secondaryForegroundColor)
            .help("隐藏书签管理器")

            Button {
                bookmarkViewModel.beginBookmarkNaming(at: playerViewModel.currentTime)
            } label: {
                Image(systemName: "plus")
            }
            .help("添加书签")
            .disabled(playerViewModel.currentRecord == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, style == .inspector ? 12 : 14)
        .background(headerBackground)
    }

    private var foregroundColor: Color {
        style == .inspector ? Color.white.opacity(0.88) : Color.white.opacity(0.9)
    }

    private var secondaryForegroundColor: Color {
        style == .inspector ? Color.white.opacity(0.50) : Color.white.opacity(0.56)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .sidebar:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.095, green: 0.105, blue: 0.125),
                        Color(red: 0.052, green: 0.058, blue: 0.070)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .inspector:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.055, green: 0.064, blue: 0.076).opacity(0.96),
                        Color(red: 0.036, green: 0.042, blue: 0.052).opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var headerBackground: some View {
        Group {
            switch style {
            case .sidebar:
                Color(red: 0.087, green: 0.097, blue: 0.116).opacity(0.78)
            case .inspector:
                Color(red: 0.070, green: 0.080, blue: 0.096).opacity(0.72)
            }
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    let message: String
    var style: BookmarkSidebarStyle = .sidebar

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 34))
                .foregroundStyle(style == .inspector ? Color.white.opacity(0.34) : Color.white.opacity(0.42))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(style == .inspector ? Color.white.opacity(0.48) : Color.white.opacity(0.56))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
