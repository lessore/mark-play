import Foundation
import SwiftData

enum VideoRecordResolver {
    static func resolve(url: URL, context: ModelContext) throws -> VideoRecord {
        let path = url.path(percentEncoded: false)
        let descriptor = FetchDescriptor<VideoRecord>(
            predicate: #Predicate { record in
                record.filePath == path
            }
        )

        if let existing = try context.fetch(descriptor).first {
            updateMetadata(for: existing, url: url)
            existing.lastOpenedAt = Date()
            try context.save()
            return existing
        }

        let record = VideoRecord(
            filePath: path,
            fileName: url.lastPathComponent,
            fileSize: fileSize(url: url),
            fileModifiedAt: fileModifiedAt(url: url)
        )
        context.insert(record)
        try context.save()
        return record
    }

    private static func updateMetadata(for record: VideoRecord, url: URL) {
        record.fileName = url.lastPathComponent
        record.fileSize = fileSize(url: url)
        record.fileModifiedAt = fileModifiedAt(url: url)
    }

    private static func fileSize(url: URL) -> Int64? {
        guard let value = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        return Int64(value)
    }

    private static func fileModifiedAt(url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
