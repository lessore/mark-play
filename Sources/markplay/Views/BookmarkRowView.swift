import SwiftUI

struct BookmarkRowView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel
    @FocusState private var isNameFocused: Bool
    @State private var draftName = ""

    let index: Int
    let bookmark: Bookmark

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("#\(index)")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.46))
                .frame(width: 34, alignment: .trailing)

            VStack(alignment: .leading, spacing: 5) {
                Text(TimeFormatter.hms(bookmark.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.white.opacity(0.52))

                if bookmarkViewModel.editingBookmarkID == bookmark.id {
                    TextField("书签名称", text: $draftName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.94))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.34))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isNameFocused ? Color(red: 0.47, green: 0.70, blue: 1.0).opacity(0.72) : Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .focused($isNameFocused)
                        .onSubmit {
                            bookmarkViewModel.rename(bookmark, to: draftName)
                        }
                        .onExitCommand {
                            draftName = bookmark.name
                            bookmarkViewModel.editingBookmarkID = nil
                        }
                        .onAppear {
                            draftName = bookmark.name
                            isNameFocused = true
                        }
                        .onChange(of: bookmarkViewModel.editingBookmarkID) { _, editingID in
                            guard editingID == bookmark.id else {
                                return
                            }
                            draftName = bookmark.name
                            isNameFocused = true
                        }
                        .onChange(of: isNameFocused) { _, focused in
                            if !focused, bookmarkViewModel.editingBookmarkID == bookmark.id {
                                bookmarkViewModel.rename(bookmark, to: draftName)
                            }
                        }
                } else {
                    Text(bookmark.name)
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(2)
                        .onTapGesture(count: 2) {
                            draftName = bookmark.name
                            bookmarkViewModel.editingBookmarkID = bookmark.id
                        }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
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
            return Color(red: 0.20, green: 0.48, blue: 0.90).opacity(0.24)
        }

        if isSelected {
            return Color.white.opacity(0.12)
        }

        return Color(red: 0.15, green: 0.16, blue: 0.19).opacity(0.72)
    }

    private var rowStroke: Color {
        if isCurrent {
            return Color(red: 0.38, green: 0.65, blue: 1.0).opacity(0.42)
        }

        if isSelected {
            return Color.white.opacity(0.18)
        }

        return Color.white.opacity(0.05)
    }
}
