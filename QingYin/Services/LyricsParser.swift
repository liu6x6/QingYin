//
//  LyricsParser.swift
//  LRC 歌词解析
//

import Foundation

struct LyricsLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

final class LyricsParser {
    static func parse(_ lrcContent: String) -> [LyricsLine] {
        var lines: [LyricsLine] = []
        let lrcLines = lrcContent.components(separatedBy: .newlines)
        
        for line in lrcLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // 匹配 [mm:ss.xx] 或 [mm:ss.xxx]
            let pattern = #"\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            
            let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
            
            guard !matches.isEmpty else { continue }
            
            // 歌词文本在最后一个时间标签之后
            let lastMatchRange = matches.last!.range
            let textStartIndex = trimmed.index(trimmed.startIndex, offsetBy: lastMatchRange.upperBound)
            let text = String(trimmed[textStartIndex...]).trimmingCharacters(in: .whitespaces)
            
            for match in matches {
                let time = parseTime(match: match, in: trimmed)
                if let time = time {
                    lines.append(LyricsLine(time: time, text: text.isEmpty ? "..." : text))
                }
            }
        }
        
        // 按时间排序并去重
        lines.sort { $0.time < $1.time }
        return lines
    }
    
    private static func parseTime(match: NSTextCheckingResult, in string: String) -> TimeInterval? {
        guard match.numberOfRanges >= 4 else { return nil }
        
        let minuteRange = match.range(at: 1)
        let secondRange = match.range(at: 2)
        let millisecondRange = match.range(at: 3)
        
        guard let minute = substring(in: string, range: minuteRange).flatMap({ TimeInterval($0) }),
              let second = substring(in: string, range: secondRange).flatMap({ TimeInterval($0) }) else {
            return nil
        }
        
        var millisecond: TimeInterval = 0
        if let msString = substring(in: string, range: millisecondRange) {
            let padded = msString.padding(toLength: 3, withPad: "0", startingAt: 0)
            millisecond = TimeInterval(padded) ?? 0
        }
        
        return minute * 60 + second + millisecond / 1000
    }
    
    private static func substring(in string: String, range: NSRange) -> String? {
        guard range.location != NSNotFound,
              let range = Range(range, in: string) else { return nil }
        return String(string[range])
    }
}

extension Array where Element == LyricsLine {
    /// 根据当前时间获取当前行索引
    func currentIndex(at time: TimeInterval) -> Int? {
        var index: Int?
        for (i, line) in enumerated() {
            if time >= line.time {
                index = i
            } else {
                break
            }
        }
        return index
    }
}
