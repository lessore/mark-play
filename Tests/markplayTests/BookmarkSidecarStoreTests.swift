import Foundation
import Testing
@testable import markplay

@Test func sidecarURLUsesBaseVideoFileName() {
    let videoURL = URL(fileURLWithPath: "/tmp/course/lesson01.mp4")
    let sidecarURL = BookmarkSidecarStore.sidecarURL(forVideoURL: videoURL)

    #expect(sidecarURL.lastPathComponent == "lesson01.mpb.json")
}

@Test func bookmarkSidecarRoundTripsBookmarks() throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    let videoURL = directoryURL.appendingPathComponent("lesson01.mp4")
    FileManager.default.createFile(atPath: videoURL.path, contents: Data())

    let record = VideoRecord(
        filePath: videoURL.path,
        fileName: videoURL.lastPathComponent,
        fileSize: 42,
        fileModifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let bookmarks = [
        Bookmark(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            timestamp: 83,
            name: "重点段落",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_200),
            video: record
        ),
        Bookmark(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            timestamp: 347,
            name: "第二段",
            createdAt: Date(timeIntervalSince1970: 1_700_000_300),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_400),
            video: record
        )
    ]

    try BookmarkSidecarStore.save(record: record, bookmarks: bookmarks)
    let loaded = try BookmarkSidecarStore.load(for: record)

    #expect(BookmarkSidecarStore.exists(for: record))
    #expect(loaded.count == 2)
    #expect(loaded.map(\.timestamp) == [83, 347])
    #expect(loaded.map(\.name) == ["重点段落", "第二段"])
}

@Test func bookmarkSidecarLoadsLegacyFileName() throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    let videoURL = directoryURL.appendingPathComponent("lesson01.mp4")
    let record = VideoRecord(filePath: videoURL.path, fileName: videoURL.lastPathComponent)
    let legacyURL = BookmarkSidecarStore.legacySidecarURL(forVideoURL: videoURL)
    let json = """
    {
      "bookmarks" : [
        {
          "createdAt" : "2026-05-08T00:00:00Z",
          "id" : "33333333-3333-3333-3333-333333333333",
          "name" : "旧文件书签",
          "timestamp" : 12.5,
          "updatedAt" : "2026-05-08T00:00:00Z"
        }
      ],
      "exportedAt" : "2026-05-08T00:00:00Z",
      "format" : "markplay.bookmarks.v1",
      "video" : {
        "fileName" : "lesson01.mp4",
        "filePath" : "\(videoURL.path)"
      }
    }
    """
    try json.data(using: .utf8)!.write(to: legacyURL)

    let loaded = try BookmarkSidecarStore.load(for: record)

    #expect(BookmarkSidecarStore.exists(for: record))
    #expect(loaded.count == 1)
    #expect(loaded.first?.name == "旧文件书签")
}

@Test func emptyBookmarksDoNotCreateSidecar() throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    let videoURL = directoryURL.appendingPathComponent("lesson01.mp4")
    FileManager.default.createFile(atPath: videoURL.path, contents: Data())

    let record = VideoRecord(
        filePath: videoURL.path,
        fileName: videoURL.lastPathComponent
    )

    try BookmarkSidecarStore.sync(record: record, bookmarks: [])

    #expect(!BookmarkSidecarStore.exists(for: record))
}

@Test func emptyBookmarksDeleteExistingSidecar() throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    let videoURL = directoryURL.appendingPathComponent("lesson01.mp4")
    FileManager.default.createFile(atPath: videoURL.path, contents: Data())

    let record = VideoRecord(
        filePath: videoURL.path,
        fileName: videoURL.lastPathComponent
    )
    let bookmarks = [
        Bookmark(timestamp: 12, name: "保留点", video: record)
    ]

    try BookmarkSidecarStore.save(record: record, bookmarks: bookmarks)
    #expect(BookmarkSidecarStore.exists(for: record))

    try BookmarkSidecarStore.sync(record: record, bookmarks: [])

    #expect(!BookmarkSidecarStore.exists(for: record))
}
