import Foundation

enum CSVExporter {
    static func makeCSV(bookmarks: [Bookmark]) -> String {
        let sorted = bookmarks.sorted { $0.timestamp < $1.timestamp }
        var rows = ["序号,时间点,书签名称"]

        for (index, bookmark) in sorted.enumerated() {
            rows.append([
                "\(index + 1)",
                TimeFormatter.hms(bookmark.timestamp),
                escape(bookmark.name)
            ].joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }

        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
