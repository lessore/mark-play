import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID
    var timestamp: Double
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var video: VideoRecord?

    init(
        id: UUID = UUID(),
        timestamp: Double,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        video: VideoRecord? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.video = video
    }
}
