import Foundation

struct PlaylistItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var fileName: String {
        url.lastPathComponent
    }
}
