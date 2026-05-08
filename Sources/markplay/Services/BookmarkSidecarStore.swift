import Foundation

enum BookmarkSidecarStore {
    static let format = "markplay.bookmarks.v1"

    static func sidecarURL(forVideoURL videoURL: URL) -> URL {
        videoURL.deletingLastPathComponent()
            .appendingPathComponent("\(videoURL.deletingPathExtension().lastPathComponent).mpb.json")
    }

    static func legacySidecarURL(forVideoURL videoURL: URL) -> URL {
        videoURL.deletingLastPathComponent()
            .appendingPathComponent("\(videoURL.lastPathComponent).markplay.json")
    }

    static func sidecarURL(for record: VideoRecord) -> URL {
        sidecarURL(forVideoURL: URL(fileURLWithPath: record.filePath))
    }

    static func exists(for record: VideoRecord) -> Bool {
        let videoURL = URL(fileURLWithPath: record.filePath)
        return FileManager.default.fileExists(atPath: sidecarURL(forVideoURL: videoURL).path)
            || FileManager.default.fileExists(atPath: legacySidecarURL(forVideoURL: videoURL).path)
    }

    static func load(for record: VideoRecord) throws -> [SidecarBookmark] {
        let videoURL = URL(fileURLWithPath: record.filePath)
        let currentURL = sidecarURL(forVideoURL: videoURL)
        let legacyURL = legacySidecarURL(forVideoURL: videoURL)
        let readableURL = FileManager.default.fileExists(atPath: currentURL.path) ? currentURL : legacyURL
        let data = try Data(contentsOf: readableURL)
        let file = try JSONDecoder.markplay.decode(SidecarFile.self, from: data)
        guard file.format == format else {
            throw SidecarError.unsupportedFormat(file.format)
        }
        return file.bookmarks
    }

    static func save(record: VideoRecord, bookmarks: [Bookmark]) throws {
        let file = SidecarFile(
            video: SidecarVideo(
                fileName: record.fileName,
                filePath: record.filePath,
                fileSize: record.fileSize,
                fileModifiedAt: record.fileModifiedAt
            ),
            bookmarks: bookmarks
                .sorted { $0.timestamp < $1.timestamp }
                .map(SidecarBookmark.init(bookmark:))
        )
        let data = try JSONEncoder.markplay.encode(file)
        let url = sidecarURL(for: record)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}

struct SidecarBookmark: Codable, Equatable {
    var id: UUID
    var timestamp: Double
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        timestamp: Double,
        name: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(bookmark: Bookmark) {
        self.init(
            id: bookmark.id,
            timestamp: bookmark.timestamp,
            name: bookmark.name,
            createdAt: bookmark.createdAt,
            updatedAt: bookmark.updatedAt
        )
    }
}

private struct SidecarFile: Codable {
    var format = BookmarkSidecarStore.format
    var exportedAt = Date()
    var video: SidecarVideo
    var bookmarks: [SidecarBookmark]
}

private struct SidecarVideo: Codable {
    var fileName: String
    var filePath: String
    var fileSize: Int64?
    var fileModifiedAt: Date?
}

enum SidecarError: LocalizedError {
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "不支持的书签文件格式：\(format)"
        }
    }
}

private extension JSONEncoder {
    static var markplay: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var markplay: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
