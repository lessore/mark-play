import Foundation

enum EmbeddedSubtitleParser {
    static func canParseFile(at url: URL) -> Bool {
        url.pathExtension.caseInsensitiveCompare("mp3") == .orderedSame
    }

    static func parse(fromFileAt url: URL) throws -> [SubtitleCue] {
        guard canParseFile(at: url) else {
            return []
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return parse(data: data)
    }

    static func parse(data: Data) -> [SubtitleCue] {
        guard let lyricsBody = lyricsFieldBody(in: data) else {
            return []
        }
        guard let decoded = decodeLyricsText(from: lyricsBody) else {
            return []
        }
        return parseTimestampedLyrics(decoded)
    }

    private static func lyricsFieldBody(in data: Data) -> Data? {
        let beginToken = Data("LYRICSBEGIN".utf8)
        let endToken = Data("LYRICS200".utf8)

        guard
            let beginRange = data.range(of: beginToken, options: .backwards),
            let endRange = data.range(of: endToken, options: .backwards),
            beginRange.upperBound < endRange.lowerBound
        else {
            return nil
        }

        let payloadRange = beginRange.upperBound..<endRange.lowerBound
        let payload = data.subdata(in: payloadRange)
        return extractLyricsField(from: payload)
    }

    private static func extractLyricsField(from payload: Data) -> Data? {
        var cursor = 0
        var lyricsData: Data?

        while cursor + 8 <= payload.count {
            let idData = payload[cursor..<(cursor + 3)]
            let sizeData = payload[(cursor + 3)..<(cursor + 8)]
            guard
                let fieldID = String(data: Data(idData), encoding: .ascii),
                let sizeText = String(data: Data(sizeData), encoding: .ascii),
                let fieldSize = Int(sizeText),
                fieldSize >= 0
            else {
                break
            }

            let valueStart = cursor + 8
            let valueEnd = valueStart + fieldSize
            guard valueEnd <= payload.count else {
                break
            }

            if fieldID == "LYR" {
                lyricsData = payload.subdata(in: valueStart..<valueEnd)
                break
            }

            cursor = valueEnd
        }

        return lyricsData
    }

    private static func decodeLyricsText(from data: Data) -> String? {
        if let gb = String(data: data, encoding: .gb18030) {
            return gb
        }
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        return String(data: data, encoding: .isoLatin1)
    }

    private static func parseTimestampedLyrics(_ text: String) -> [SubtitleCue] {
        let pattern = #"\[(\d{2}):(\d{2})(?:\.(\d{1,2}))?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        var entries: [(start: Double, text: String)] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, options: [], range: range)
            guard !matches.isEmpty else {
                continue
            }

            let stripped = regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "")
            let cueText = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cueText.isEmpty else {
                continue
            }

            for match in matches {
                guard let start = parseTimestamp(match: match, in: line) else {
                    continue
                }
                entries.append((start, cueText))
            }
        }

        guard !entries.isEmpty else {
            return []
        }

        entries.sort { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.text < rhs.text
            }
            return lhs.start < rhs.start
        }

        var cues: [SubtitleCue] = []
        cues.reserveCapacity(entries.count)
        for index in entries.indices {
            let current = entries[index]
            let nextStart = index + 1 < entries.count ? entries[index + 1].start : nil
            let endTime = nextStart.flatMap { $0 > current.start ? $0 : nil }
            cues.append(
                SubtitleCue(
                    id: index,
                    startTime: current.start,
                    endTime: endTime,
                    text: current.text
                )
            )
        }
        return cues
    }

    private static func parseTimestamp(match: NSTextCheckingResult, in line: String) -> Double? {
        func part(_ index: Int) -> String? {
            guard
                let range = Range(match.range(at: index), in: line)
            else {
                return nil
            }
            return String(line[range])
        }

        guard
            let minuteText = part(1),
            let secondText = part(2),
            let minute = Double(minuteText),
            let second = Double(secondText)
        else {
            return nil
        }

        let decimal: Double
        if let fractionText = part(3), !fractionText.isEmpty {
            decimal = Double("0.\(fractionText)") ?? 0
        } else {
            decimal = 0
        }
        return minute * 60 + second + decimal
    }
}

extension String.Encoding {
    static let gb18030: String.Encoding = {
        let encoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(encoding)
        return String.Encoding(rawValue: nsEncoding)
    }()
}
