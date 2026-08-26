//
//  AudioMetadataExtractor.swift
//  提取音频文件元数据
//

import Foundation
import AVFoundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AudioMetadata {
    var title: String?
    var artist: String?
    var album: String?
    var duration: TimeInterval = 0
    
    #if os(macOS)
    var artwork: NSImage? = nil
    #else
    var artwork: UIImage? = nil
    #endif
}

final class AudioMetadataExtractor {
    static func extract(from url: URL) -> AudioMetadata {
        var metadata = AudioMetadata()
        
        let asset = AVAsset(url: url)
        
        // 时长
        let duration = asset.duration
        if duration.isValid {
            metadata.duration = CMTimeGetSeconds(duration)
        }
        
        // ID3 元数据
        for item in asset.commonMetadata {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                metadata.title = item.stringValue
            case .commonKeyArtist:
                metadata.artist = item.stringValue
            case .commonKeyAlbumName:
                metadata.album = item.stringValue
            case .commonKeyArtwork:
                if let dataValue = item.value as? Data {
                    #if os(macOS)
                    metadata.artwork = NSImage(data: dataValue)
                    #else
                    metadata.artwork = UIImage(data: dataValue)
                    #endif
                }
            default:
                break
            }
        }
        
        return metadata
    }
}

extension AVMetadataItem {
    fileprivate var stringValue: String? {
        return value as? String
    }
}
