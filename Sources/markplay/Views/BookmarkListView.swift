import SwiftUI

struct BookmarkListView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(bookmarkViewModel.sortedBookmarks.enumerated()), id: \.element.id) { index, bookmark in
                        BookmarkRowView(index: index + 1, bookmark: bookmark)
                        .id(bookmark.id)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .simultaneousGesture(TapGesture(count: 1).onEnded {
                            if bookmarkViewModel.editingBookmarkID != bookmark.id {
                                bookmarkViewModel.finishEditingBookmark()
                            }
                            bookmarkViewModel.selectedBookmarkID = bookmark.id
                        })
                        .highPriorityGesture(TapGesture(count: 2).onEnded {
                            if bookmarkViewModel.editingBookmarkID != bookmark.id {
                                bookmarkViewModel.finishEditingBookmark()
                            }
                            bookmarkViewModel.selectedBookmarkID = bookmark.id
                            playerViewModel.seek(to: bookmark.timestamp)
                        })
                        .contextMenu {
                            Button("跳转到此位置") {
                                playerViewModel.seek(to: bookmark.timestamp)
                            }
                            Button("重命名") {
                                bookmarkViewModel.beginEditing(bookmark)
                            }
                            Divider()
                            Button("复制时间") {
                                bookmarkViewModel.copyTime(bookmark)
                            }
                            Button("复制名称") {
                                bookmarkViewModel.copyName(bookmark)
                            }
                            Divider()
                            Button("删除", role: .destructive) {
                                bookmarkViewModel.delete(bookmark)
                            }
                            Button("删除全部书签", role: .destructive) {
                                bookmarkViewModel.showDeleteAllConfirmation = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .background(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                bookmarkViewModel.finishEditingBookmark()
            }
            .onChange(of: bookmarkViewModel.editingBookmarkID) { _, id in
                guard let id else {
                    return
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onDeleteCommand {
                bookmarkViewModel.deleteSelected()
            }
        }
    }
}
