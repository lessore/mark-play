import Foundation
import SwiftData

@MainActor
final class PlaylistViewModel: ObservableObject {
    @Published private(set) var items: [PlaylistItem] = []
    @Published var currentItemID: PlaylistItem.ID?
    @Published var errorMessage: String?

    var currentIndex: Int? {
        guard let currentItemID else {
            return nil
        }
        return items.firstIndex { $0.id == currentItemID }
    }

    var hasItems: Bool {
        !items.isEmpty
    }

    func append(urls: [URL], context: ModelContext, playerViewModel: PlayerViewModel) {
        let mp3URLs = expandMP3URLs(from: urls)
        guard !mp3URLs.isEmpty else {
            errorMessage = "未找到可加入播放列表的 MP3 文件。"
            return
        }

        var seenPaths = Set(items.map { normalizedPath(for: $0.url) })
        let newItems = mp3URLs.compactMap { url -> PlaylistItem? in
            let path = normalizedPath(for: url)
            guard !seenPaths.contains(path) else {
                return nil
            }
            seenPaths.insert(path)
            return PlaylistItem(url: url)
        }

        guard !newItems.isEmpty else {
            errorMessage = "这些 MP3 已在播放列表中。"
            return
        }

        let shouldStartPlayback = currentItemID == nil && playerViewModel.currentURL == nil
        items.append(contentsOf: newItems)
        errorMessage = nil

        if shouldStartPlayback, let firstNewItem = newItems.first {
            play(itemID: firstNewItem.id, context: context, playerViewModel: playerViewModel)
        }
    }

    func play(itemID: PlaylistItem.ID, context: ModelContext, playerViewModel: PlayerViewModel) {
        guard let item = items.first(where: { $0.id == itemID }) else {
            return
        }
        currentItemID = itemID
        playerViewModel.openMedia(url: item.url, context: context)
    }

    func playNext(context: ModelContext, playerViewModel: PlayerViewModel) {
        guard let currentIndex else {
            playFirstIfAvailable(context: context, playerViewModel: playerViewModel)
            return
        }

        let nextIndex = currentIndex + 1
        guard items.indices.contains(nextIndex) else {
            currentItemID = nil
            return
        }

        play(itemID: items[nextIndex].id, context: context, playerViewModel: playerViewModel)
    }

    func remove(itemID: PlaylistItem.ID) {
        let wasCurrentItem = currentItemID == itemID
        items.removeAll { $0.id == itemID }
        if wasCurrentItem {
            currentItemID = nil
        }
    }

    func clear() {
        items.removeAll()
        currentItemID = nil
        errorMessage = nil
    }

    private func playFirstIfAvailable(context: ModelContext, playerViewModel: PlayerViewModel) {
        guard let firstItem = items.first else {
            currentItemID = nil
            return
        }
        play(itemID: firstItem.id, context: context, playerViewModel: playerViewModel)
    }

    private func expandMP3URLs(from urls: [URL]) -> [URL] {
        let fileManager = FileManager.default
        return urls.flatMap { url -> [URL] in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) else {
                return []
            }

            if isDirectory.boolValue {
                return mp3URLs(in: url)
            }

            return isMP3(url) ? [url] : []
        }
    }

    private func mp3URLs(in folderURL: URL) -> [URL] {
        let fileManager = FileManager.default
        let urls = (try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { isMP3($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func isMP3(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "mp3"
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.path(percentEncoded: false)
    }
}
