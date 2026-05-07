import Foundation
import SwiftData

@Model
final class VideoRecord {
    var id: UUID
    var filePath: String
    var fileName: String
    var fileSize: Int64?
    var fileModifiedAt: Date?
    var bookmarkData: Data?
    var lastOpenedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.video)
    var bookmarks: [Bookmark]

    init(
        id: UUID = UUID(),
        filePath: String,
        fileName: String,
        fileSize: Int64? = nil,
        fileModifiedAt: Date? = nil,
        bookmarkData: Data? = nil,
        lastOpenedAt: Date = Date(),
        bookmarks: [Bookmark] = []
    ) {
        self.id = id
        self.filePath = filePath
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileModifiedAt = fileModifiedAt
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
        self.bookmarks = bookmarks
    }
}
