import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct Song: Identifiable, Equatable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let assetURL: URL?
    let lyrics: String?
    
    #if os(macOS)
    let artworkImage: NSImage?
    #else
    let artworkImage: UIImage?
    #endif
    
    var artwork: Image? {
        guard let artworkImage = artworkImage else { return nil }
        #if os(macOS)
        return Image(nsImage: artworkImage)
        #else
        return Image(uiImage: artworkImage)
        #endif
    }
    
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Song {
    /// 根据字符串生成稳定的 UUID（name-based，基于 FNV-1a 变体）
    static func stableID(from string: String) -> UUID {
        let data = Array(string.utf8)
        var bytes = Array(repeating: UInt8(0), count: 16)
        
        // FNV-1a 填充全部 16 字节
        for round in 0..<4 {
            var h: UInt64 = 0xcbf29ce484222325 ^ UInt64(round)
            for byte in data {
                h ^= UInt64(byte)
                h = h &* 0x100000001b3
            }
            bytes[round * 4 + 0] = UInt8((h >>  0) & 0xFF)
            bytes[round * 4 + 1] = UInt8((h >>  8) & 0xFF)
            bytes[round * 4 + 2] = UInt8((h >> 16) & 0xFF)
            bytes[round * 4 + 3] = UInt8((h >> 24) & 0xFF)
        }
        
        bytes[6] = (bytes[6] & 0x0F) | 0x50  // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant 1
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
    
    /// 根据文件路径生成稳定 UUID
    static func stableID(forFilePath path: String) -> UUID {
        stableID(from: "file:\(path)")
    }
}

#if DEBUG
extension Song {
    static let sampleSongs: [Song] = [
        Song(
            id: stableID(from: "sample:夜曲:周杰伦"),
            title: "夜曲",
            artist: "周杰伦",
            album: "十一月的萧邦",
            duration: 299,
            assetURL: nil,
            lyrics: sampleLyrics,
            artworkImage: nil
        ),
        Song(
            id: stableID(from: "sample:晴天:周杰伦"),
            title: "晴天",
            artist: "周杰伦",
            album: "叶惠美",
            duration: 269,
            assetURL: nil,
            lyrics: nil,
            artworkImage: nil
        ),
        Song(
            id: stableID(from: "sample:稻香:周杰伦"),
            title: "稻香",
            artist: "周杰伦",
            album: "魔杰座",
            duration: 222,
            assetURL: nil,
            lyrics: nil,
            artworkImage: nil
        ),
        Song(
            id: stableID(from: "sample:七里香:周杰伦"),
            title: "七里香",
            artist: "周杰伦",
            album: "七里香",
            duration: 299,
            assetURL: nil,
            lyrics: nil,
            artworkImage: nil
        ),
        Song(
            id: stableID(from: "sample:简单爱:周杰伦"),
            title: "简单爱",
            artist: "周杰伦",
            album: "范特西",
            duration: 271,
            assetURL: nil,
            lyrics: nil,
            artworkImage: nil
        ),
        Song(
            id: stableID(from: "sample:告白气球:周杰伦"),
            title: "告白气球",
            artist: "周杰伦",
            album: "周杰伦的床边故事",
            duration: 206,
            assetURL: nil,
            lyrics: nil,
            artworkImage: nil
        )
    ]
    
    private static let sampleLyrics = """
    [00:00.00] 夜曲
    [00:12.00] 一群嗜血的蚂蚁 被腐肉所吸引
    [00:15.00] 我面无表情 看孤独的风景
    [00:19.00] 失去你 爱恨开始分明
    [00:22.00] 失去你 还有什么事好关心
    [00:26.00] 当鸽子不再象征和平
    [00:29.00] 我终于被提醒
    [00:31.00] 广场上喂食的是秃鹰
    [00:35.00] 我用漂亮的押韵
    [00:37.00] 形容被掠夺一空的爱情
    """
}
#endif
