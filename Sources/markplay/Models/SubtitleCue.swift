import Foundation

struct SubtitleCue: Identifiable, Equatable {
    let id: Int
    let startTime: Double
    let endTime: Double?
    let text: String

    func contains(_ time: Double) -> Bool {
        guard let endTime else {
            return time >= startTime
        }
        return time >= startTime && time < endTime
    }
}
