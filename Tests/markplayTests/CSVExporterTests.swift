import Testing
@testable import markplay

@Test func timeFormatterUsesHHMMSS() {
    #expect(TimeFormatter.hms(0) == "00:00:00")
    #expect(TimeFormatter.hms(83) == "00:01:23")
    #expect(TimeFormatter.hms(3661.9) == "01:01:01")
}

@Test func csvExporterEscapesSpecialFields() {
    let bookmarks = [
        Bookmark(timestamp: 83, name: "重要片段"),
        Bookmark(timestamp: 347, name: "包含,逗号的名称"),
        Bookmark(timestamp: 720, name: "他说\"这里重要\""),
        Bookmark(timestamp: 900, name: "第一行\n第二行")
    ]

    let csv = CSVExporter.makeCSV(bookmarks: bookmarks)

    #expect(csv.contains("序号,时间点,书签名称"))
    #expect(csv.contains("1,00:01:23,重要片段"))
    #expect(csv.contains("2,00:05:47,\"包含,逗号的名称\""))
    #expect(csv.contains("3,00:12:00,\"他说\"\"这里重要\"\"\""))
    #expect(csv.contains("4,00:15:00,\"第一行\n第二行\""))
}
