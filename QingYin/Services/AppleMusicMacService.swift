//
//  AppleMusicMacService.swift
//  读取 macOS Apple Music 本地音乐文件
//

import Foundation


#if os(macOS)
import AppKit

@MainActor
final class AppleMusicMacService {
    static let shared = AppleMusicMacService()

    private struct CachedSong: Codable {
        let id: UUID
        let title: String
        let artist: String
        let album: String
        let duration: TimeInterval
        let filePath: String
    }

    private let cacheKey = "qingyin.appleMusicLocalLibrary"
    
    private init() {}
    
    /// 扫描 Apple Music 本地文件
    func scanAppleMusicLibrary() -> [Song] {
        var songs: [Song] = []
        
        // Apple Music 本地文件可能存放的路径
        let searchPaths = [
            homePath.appendingPathComponent("Music/Music/Media.localized"),
            homePath.appendingPathComponent("Music/Music"),
            homePath.appendingPathComponent("Music/iTunes/iTunes Media/Music")
        ]
        
        for basePath in searchPaths {
            guard FileManager.default.fileExists(atPath: basePath.path) else { continue }
            let foundSongs = scanDirectory(basePath)
            songs.append(contentsOf: foundSongs)
        }
        
        return songs
    }

    /// 恢复上次扫描的索引，避免每次启动都遍历 Apple Music 文件夹。
    func restoreCachedLibrary() -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cachedSongs = try? JSONDecoder().decode([CachedSong].self, from: data) else {
            return []
        }

        return cachedSongs.compactMap { cachedSong in
            let url = URL(fileURLWithPath: cachedSong.filePath)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return Song(
                id: cachedSong.id,
                title: cachedSong.title,
                artist: cachedSong.artist,
                album: cachedSong.album,
                duration: cachedSong.duration,
                assetURL: url,
                lyrics: nil,
                artworkImage: nil
            )
        }
    }

    func cacheLibrary(_ songs: [Song]) {
        let cachedSongs = songs.compactMap { song -> CachedSong? in
            guard let url = song.assetURL else { return nil }
            return CachedSong(
                id: song.id,
                title: song.title,
                artist: song.artist,
                album: song.album,
                duration: song.duration,
                filePath: url.path
            )
        }

        guard let data = try? JSONEncoder().encode(cachedSongs) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
    
    private var homePath: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
    
    private func scanDirectory(_ url: URL) -> [Song] {
        var songs: [Song] = []
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return songs
        }
        
        while let fileURL = enumerator.nextObject() as? URL {
            guard isAudioFile(fileURL) else { continue }
            
            let metadata = AudioMetadataExtractor.extract(from: fileURL)
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            
            let song = Song(
                id: Song.stableID(forFilePath: fileURL.path),
                title: metadata.title ?? fileName,
                artist: metadata.artist ?? "未知艺术家",
                album: metadata.album ?? "",
                duration: metadata.duration,
                assetURL: fileURL,
                lyrics: nil,
                artworkImage: metadata.artwork
            )
            songs.append(song)
        }
        
        return songs
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg"].contains(ext)
    }
}

#endif
