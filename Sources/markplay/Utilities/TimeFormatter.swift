import Foundation

enum TimeFormatter {
    static func hms(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "00:00:00"
        }

        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}
