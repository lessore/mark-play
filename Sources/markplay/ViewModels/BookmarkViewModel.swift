import AppKit
import Foundation
import SwiftData

@MainActor
final class BookmarkViewModel: ObservableObject {
    @Published var editingBookmarkID: UUID?
    @Published var selectedBookmarkID: UUID?
    @Published var showDeleteAllConfirmation = false
    @Published var isNamingBookmark = false
    @Published var pendingBookmarkName = ""
    @Published var exportErrorMessage: String?

    private var pendingBookmarkTimestamp: Double?
    var sortedBookmarks: [Bookmark] {
        currentRecord?.bookmarks.sorted { $0.timestamp < $1.timestamp } ?? []
    }

    private var currentRecord: VideoRecord?
    private var context: ModelContext?

    func bind(record: VideoRecord?, context: ModelContext) {
        currentRecord = record
        self.context = context
        if record == nil {
            editingBookmarkID = nil
            selectedBookmarkID = nil
            isNamingBookmark = false
            pendingBookmarkName = ""
            pendingBookmarkTimestamp = nil
        }
    }

    func beginBookmarkNaming(at timestamp: Double) {
        guard currentRecord != nil else {
            return
        }

        let baseName = "书签 \(TimeFormatter.hms(timestamp))"
        pendingBookmarkTimestamp = timestamp
        pendingBookmarkName = uniqueName(baseName: baseName, timestamp: timestamp)
        isNamingBookmark = true
    }

    func confirmPendingBookmark() {
        guard let timestamp = pendingBookmarkTimestamp else {
            cancelPendingBookmark()
            return
        }

        addBookmark(at: timestamp, name: pendingBookmarkName)
        cancelPendingBookmark()
    }

    func cancelPendingBookmark() {
        isNamingBookmark = false
        pendingBookmarkName = ""
        pendingBookmarkTimestamp = nil
    }

    private func addBookmark(at timestamp: Double, name: String) {
        guard let currentRecord, let context else {
            return
        }

        let baseName = "书签 \(TimeFormatter.hms(timestamp))"
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? uniqueName(baseName: baseName, timestamp: timestamp) : trimmedName
        let bookmark = Bookmark(timestamp: timestamp, name: finalName, video: currentRecord)
        currentRecord.bookmarks.append(bookmark)
        context.insert(bookmark)
        save()
        selectedBookmarkID = bookmark.id
    }

    func rename(_ bookmark: Bookmark, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editingBookmarkID = nil
            return
        }

        bookmark.name = trimmed
        bookmark.updatedAt = Date()
        save()
        editingBookmarkID = nil
    }

    func delete(_ bookmark: Bookmark) {
        guard let context else {
            return
        }

        context.delete(bookmark)
        if selectedBookmarkID == bookmark.id {
            selectedBookmarkID = nil
        }
        if editingBookmarkID == bookmark.id {
            editingBookmarkID = nil
        }
        save()
    }

    func deleteSelected() {
        guard let selectedBookmarkID,
              let bookmark = sortedBookmarks.first(where: { $0.id == selectedBookmarkID }) else {
            return
        }
        delete(bookmark)
    }

    func deleteAll() {
        guard let currentRecord, let context else {
            return
        }

        for bookmark in currentRecord.bookmarks {
            context.delete(bookmark)
        }
        currentRecord.bookmarks.removeAll()
        selectedBookmarkID = nil
        editingBookmarkID = nil
        save()
    }

    func copyTime(_ bookmark: Bookmark) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(TimeFormatter.hms(bookmark.timestamp), forType: .string)
    }

    func copyName(_ bookmark: Bookmark) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bookmark.name, forType: .string)
    }

    func exportCSV() {
        guard let currentRecord else {
            exportErrorMessage = "没有可导出的当前视频。"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(currentRecord.fileName)_bookmarks.csv"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let csv = CSVExporter.makeCSV(bookmarks: sortedBookmarks)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportErrorMessage = nil
        } catch {
            exportErrorMessage = "CSV 导出失败：\(error.localizedDescription)"
        }
    }

    private func uniqueName(baseName: String, timestamp: Double) -> String {
        guard let currentRecord else {
            return baseName
        }

        let hasSameTimestamp = currentRecord.bookmarks.contains {
            abs($0.timestamp - timestamp) < 0.001
        }

        guard hasSameTimestamp else {
            return baseName
        }

        var index = 2
        var candidate = "\(baseName) \(index)"
        let names = Set(currentRecord.bookmarks.map(\.name))
        while names.contains(candidate) {
            index += 1
            candidate = "\(baseName) \(index)"
        }
        return candidate
    }

    private func save() {
        do {
            try context?.save()
            objectWillChange.send()
        } catch {
            exportErrorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
