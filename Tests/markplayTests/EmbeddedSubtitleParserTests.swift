import Foundation
import Testing
@testable import markplay

@Test func embeddedSubtitleParserParsesLyrics3WithGB18030() throws {
    let lyricBody = """
[ti:]
[00:01.20]第一句
[00:03.40][00:05.00]重复句
"""
    let lyricData = try #require(lyricBody.data(using: .gb18030))

    let payload = makeLyrics3Payload(lyricData: lyricData)
    let audioStub = Data(repeating: 0x55, count: 128)
    let data = audioStub + payload + Data(repeating: 0x00, count: 32)

    let cues = EmbeddedSubtitleParser.parse(data: data)

    #expect(cues.count == 3)
    #expect(cues.map(\.text) == ["第一句", "重复句", "重复句"])
    #expect(cues.map(\.startTime) == [1.2, 3.4, 5.0])
    #expect(cues[0].endTime == 3.4)
    #expect(cues[1].endTime == 5.0)
    #expect(cues[2].endTime == nil)
}

@Test func embeddedSubtitleParserReturnsEmptyWhenNoLyrics3Tag() {
    let data = Data("plain-mp3-data".utf8)
    let cues = EmbeddedSubtitleParser.parse(data: data)

    #expect(cues.isEmpty)
}

@Test func embeddedSubtitleParserIgnoresLinesWithoutText() throws {
    let lyricBody = """
[00:01.20]
[00:02.00]    
[00:03.00]有效行
"""
    let lyricData = try #require(lyricBody.data(using: .utf8))
    let payload = makeLyrics3Payload(lyricData: lyricData)
    let data = Data(repeating: 0x10, count: 64) + payload

    let cues = EmbeddedSubtitleParser.parse(data: data)

    #expect(cues.count == 1)
    #expect(cues.first?.text == "有效行")
    #expect(cues.first?.startTime == 3.0)
}

private func makeLyrics3Payload(lyricData: Data) -> Data {
    let indValue = "110"
    let indField = Data("IND\(String(format: "%05d", indValue.count))\(indValue)".utf8)
    let lyricHeader = Data("LYR\(String(format: "%05d", lyricData.count))".utf8)
    let fieldData = indField + lyricHeader + lyricData

    // Lyrics3 v2 在末尾会附带一个 6 位长度字段，这里保留该结构以贴近真实文件。
    let lengthField = String(format: "%06d", fieldData.count + 11 + 9 + 6)
    return Data("LYRICSBEGIN".utf8) + fieldData + Data(lengthField.utf8) + Data("LYRICS200".utf8)
}
