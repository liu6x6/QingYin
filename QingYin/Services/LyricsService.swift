//
//  LyricsService.swift
//  歌词搜索与缓存服务（基于 LRCLIB API）
//

import Foundation

@MainActor
final class LyricsService {
    static let shared = LyricsService()
    
    private let baseURL = "https://lrclib.net/api"
    private let session: URLSession
    
    private var lyricsDirectory: URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = documents.appendingPathComponent("Lyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // 内存缓存，避免重复读磁盘
    private var memoryCache: [UUID: String?] = [:]
    // 防止同一首歌并发请求
    private var pendingRequests: Set<UUID> = []
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// 获取歌词：先查缓存，再查 API
    /// - Returns: LRC 歌词文本，或 nil（未找到/正在搜索中）
    func getLyrics(for song: Song) async -> String? {
        // 1. 歌曲自带歌词（本地 .lrc 文件）
        if let embedded = song.lyrics, !embedded.isEmpty {
            return embedded
        }
        
        // 2. 内存缓存
        if let cached = memoryCache[song.id] {
            return cached
        }
        
        // 3. 磁盘缓存
        if let diskCached = loadFromDisk(songID: song.id) {
            memoryCache[song.id] = diskCached
            return diskCached
        }
        
        // 4. 正在请求中，不重复发起
        guard !pendingRequests.contains(song.id) else { return nil }
        
        // 5. 在线搜索
        return await searchAndCache(for: song)
    }
    
    /// 强制重新搜索（忽略缓存）
    func refreshLyrics(for song: Song) async -> String? {
        pendingRequests.remove(song.id)
        return await searchAndCache(for: song)
    }
    
    /// 删除缓存
    func clearCache(for songID: UUID) {
        memoryCache.removeValue(forKey: songID)
        guard let dir = lyricsDirectory else { return }
        let file = dir.appendingPathComponent("\(songID.uuidString).lrc")
        try? FileManager.default.removeItem(at: file)
    }
    
    // MARK: - LRCLIB API
    
    /// LRCLIB 搜索结果
    private struct LRCLIBResult: Codable {
        let trackName: String?
        let artistName: String?
        let syncedLyrics: String?
        let plainLyrics: String?
    }
    
    private func searchAndCache(for song: Song) async -> String? {
        pendingRequests.insert(song.id)
        defer { pendingRequests.remove(song.id) }
        
        print("🔍 搜索歌词: \(song.title) - \(song.artist)")
        
        // 策略1: 精确匹配（标题 + 艺术家）
        if let lrc = try? await searchExact(title: song.title, artist: song.artist) {
            return cacheLyrics(lrc, for: song.id)
        }
        
        // 策略2: 模糊搜索（仅标题）
        if let lrc = try? await searchFuzzy(query: song.title) {
            return cacheLyrics(lrc, for: song.id)
        }
        
        // 策略3: 标题 + 艺术家一起搜索
        if let lrc = try? await searchFuzzy(query: "\(song.title) \(song.artist)") {
            return cacheLyrics(lrc, for: song.id)
        }
        
        print("⚠️ 未找到歌词: \(song.title)")
        // 缓存空结果，避免反复搜索
        memoryCache[song.id] = nil
        return nil
    }
    
    /// 精确匹配: /api/get?artist_name=X&track_name=X
    private func searchExact(title: String, artist: String) async throws -> String? {
        var components = URLComponents(string: "\(baseURL)/get")!
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title),
        ]
        guard let url = components.url else { return nil }
        
        let (data, response) = try await session.data(from: url)
        guard let httpResp = response as? HTTPURLResponse else { return nil }
        
        // 404 = 未找到，不是错误
        if httpResp.statusCode == 404 { return nil }
        guard httpResp.statusCode == 200 else { return nil }
        
        let result = try JSONDecoder().decode(LRCLIBResult.self, from: data)
        return result.syncedLyrics ?? result.plainLyrics
    }
    
    /// 模糊搜索: /api/search?q=X
    private func searchFuzzy(query: String) async throws -> String? {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
        ]
        guard let url = components.url else { return nil }
        
        let (data, response) = try await session.data(from: url)
        guard let httpResp = response as? HTTPURLResponse,
              httpResp.statusCode == 200 else { return nil }
        
        let results = try JSONDecoder().decode([LRCLIBResult].self, from: data)
        
        // 优先选有 syncedLyrics（带时间轴的 LRC）的结果
        if let synced = results.first(where: { $0.syncedLyrics != nil })?.syncedLyrics {
            return synced
        }
        // 退而求其次选 plainLyrics
        return results.first(where: { $0.plainLyrics != nil })?.plainLyrics
    }
    
    // MARK: - 磁盘缓存
    
    private func cacheLyrics(_ lrc: String, for songID: UUID) -> String {
        memoryCache[songID] = lrc
        saveToDisk(lrc, songID: songID)
        print("✅ 歌词已缓存: \(songID.uuidString.prefix(8))...")
        return lrc
    }
    
    private func saveToDisk(_ lrc: String, songID: UUID) {
        guard let dir = lyricsDirectory else { return }
        let file = dir.appendingPathComponent("\(songID.uuidString).lrc")
        try? lrc.write(to: file, atomically: true, encoding: .utf8)
    }
    
    private func loadFromDisk(songID: UUID) -> String? {
        guard let dir = lyricsDirectory else { return nil }
        let file = dir.appendingPathComponent("\(songID.uuidString).lrc")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try? String(contentsOf: file, encoding: .utf8)
    }
}
