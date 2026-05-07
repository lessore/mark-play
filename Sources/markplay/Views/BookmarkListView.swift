import SwiftUI

struct BookmarkListView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(bookmarkViewModel.sortedBookmarks.enumerated()), id: \.element.id) { index, bookmark in
                        BookmarkRowView(index: index + 1, bookmark: bookmark)
                        .id(bookmark.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            bookmarkViewModel.selectedBookmarkID = bookmark.id
                            playerViewModel.seek(to: bookmark.timestamp)
                        }
                        .contextMenu {
                            Button("跳转到此位置") {
                                playerViewModel.seek(to: bookmark.timestamp)
                            }
                            Button("重命名") {
                                bookmarkViewModel.editingBookmarkID = bookmark.id
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
                .padding(10)
            }
            .background(Color.clear)
            .onChange(of: bookmarkViewModel.editingBookmarkID) { _, id in
                guard let id else {
                    return
                }
                withAnimation {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onDeleteCommand {
                bookmarkViewModel.deleteSelected()
            }
        }
    }
}
