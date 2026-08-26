//
//  LocalFileService.swift
//  本地音频文件导入与管理
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

enum AudioFileError: Error, LocalizedError {
    case documentsDirectoryNotFound
    case copyFailed(Error)
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "找不到应用文档目录"
        case .copyFailed(let error):
            return "文件拷贝失败: \(error.localizedDescription)"
        case .unsupportedFormat:
            return "不支持的音频格式"
        }
    }
}

@MainActor
final class LocalFileService: ObservableObject {
    static let shared = LocalFileService()
    
    @Published var importedSongs: [Song] = []
    
    /// 支持的音频格式
    static let supportedContentTypes: [UTType] = [
        .mp3,
        .mpeg4Audio,
        .wav,
        .aiff,
        UTType.audio,
        UTType("public.flac")
//        UTType(importedAs: "public.flac"),
//        UTType(importedAs: "public.audio")
    ].compactMap { $0 }
    
    /// 音频文件存放目录
    private var audioDirectory: URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let audioDir = documentsPath.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        return audioDir
    }
    
    private init() {
        scanImportedFiles()
    }
    
    /// 导入单个音频文件
    /// 如果同名文件已存在，直接返回已有歌曲（不重复拷贝）
    func importAudioFile(from url: URL) throws -> Song {
        guard let audioDir = audioDirectory else {
            throw AudioFileError.documentsDirectoryNotFound
        }
        
        let destinationURL = audioDir.appendingPathComponent(url.lastPathComponent)
        
        // 如果同名文件已存在，直接返回已有歌曲，避免重复
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return createSong(from: destinationURL)
        }
        
        let uniqueURL = uniqueURL(for: destinationURL)
        
        do {
            // 安全拷贝（iOS 需要访问安全域内的文件）
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try FileManager.default.copyItem(at: url, to: uniqueURL)
        } catch {
            throw AudioFileError.copyFailed(error)
        }
        
        let song = createSong(from: uniqueURL)
        scanImportedFiles()
        return song
    }
    
    /// 导入歌词文件（与音频同名的 .lrc）
    func importLyricsFile(forAudioURL audioURL: URL) -> String? {
        let lrcURL = audioURL.deletingPathExtension().appendingPathExtension("lrc")
        guard FileManager.default.fileExists(atPath: lrcURL.path) else { return nil }
        do {
            return try String(contentsOf: lrcURL, encoding: .utf8)
        } catch {
            print("读取歌词失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 批量导入多个文件
    func importAudioFiles(from urls: [URL]) -> [Song] {
        var imported: [Song] = []
        for url in urls {
            do {
                let song = try importAudioFile(from: url)
                imported.append(song)
            } catch {
                print("导入失败: \(error.localizedDescription)")
            }
        }
        return imported
    }
    
    /// 扫描已导入文件
    func scanImportedFiles() {
        guard let audioDir = audioDirectory else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)
            let audioURLs = fileURLs.filter { isSupportedAudioFile($0) }
            
            importedSongs = audioURLs.map { createSong(from: $0) }
        } catch {
            print("扫描文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 删除已导入文件
    func deleteImportedSong(_ song: Song) {
        guard let url = song.assetURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            scanImportedFiles()
        } catch {
            print("删除失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    private func createSong(from url: URL) -> Song {
        let fileName = url.deletingPathExtension().lastPathComponent
        let metadata = AudioMetadataExtractor.extract(from: url)
        let lyrics = importLyricsFile(forAudioURL: url)
        
        // 用文件路径生成稳定 UUID，保证同一文件重启后 ID 不变
        let stableID = Song.stableID(forFilePath: url.path)
        
        return Song(
            id: stableID,
            title: metadata.title ?? fileName,
            artist: metadata.artist ?? "本地音乐",
            album: metadata.album ?? "",
            duration: metadata.duration,
            assetURL: url,
            lyrics: lyrics,
            artworkImage: metadata.artwork
        )
    }
    
    private func isSupportedAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg"].contains(ext)
    }
    
    private func uniqueURL(for url: URL) -> URL {
        var uniqueURL = url
        var counter = 1
        while FileManager.default.fileExists(atPath: uniqueURL.path) {
            let fileName = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            uniqueURL = url.deletingLastPathComponent()
                .appendingPathComponent("\(fileName)_\(counter).\(ext)")
            counter += 1
        }
        return uniqueURL
    }
}
