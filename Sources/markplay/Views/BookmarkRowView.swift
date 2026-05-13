import SwiftUI

struct BookmarkRowView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel
    @FocusState private var isNameFocused: Bool

    let index: Int
    let bookmark: Bookmark

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(TimeFormatter.hms(bookmark.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(timeColor)
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                if bookmarkViewModel.editingBookmarkID == bookmark.id {
                    TextField("书签名称", text: $bookmarkViewModel.editingBookmarkName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.94))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isNameFocused ? Color.accentColor.opacity(0.72) : Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .focused($isNameFocused)
                        .onSubmit {
                            bookmarkViewModel.finishEditingBookmark()
                        }
                        .onExitCommand {
                            bookmarkViewModel.cancelEditingBookmark()
                        }
                        .onAppear {
                            isNameFocused = true
                        }
                        .onChange(of: bookmarkViewModel.editingBookmarkID) { _, editingID in
                            guard editingID == bookmark.id else {
                                return
                            }
                            isNameFocused = true
                        }
                        .onChange(of: isNameFocused) { _, focused in
                            if !focused, bookmarkViewModel.editingBookmarkID == bookmark.id {
                                bookmarkViewModel.finishEditingBookmark()
                            }
                        }
                } else {
                    Text(bookmark.name)
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(rowStroke, lineWidth: 1)
        )
    }

    private var isCurrent: Bool {
        abs(playerViewModel.currentTime - bookmark.timestamp) <= 1
    }

    private var isSelected: Bool {
        bookmarkViewModel.selectedBookmarkID == bookmark.id
    }

    private var rowBackground: Color {
        if isCurrent {
            return Color.accentColor.opacity(0.18)
        }

        if isSelected {
            return Color.white.opacity(0.10)
        }

        return Color.clear
    }

    private var rowStroke: Color {
        if isCurrent {
            return Color.accentColor.opacity(0.28)
        }

        if isSelected {
            return Color.white.opacity(0.16)
        }

        return Color.clear
    }

    private var timeColor: Color {
        if isCurrent {
            return .accentColor
        }
        if isSelected {
            return Color.white.opacity(0.90)
        }
        return Color.white.opacity(0.64)
    }
}
