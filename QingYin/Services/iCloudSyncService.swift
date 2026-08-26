//
//  iCloudSyncService.swift
//  iCloud 同步服务
//

import Foundation
import CloudKit

/// 使用 NSUbiquitousKeyValueStore 同步轻量数据（播放列表、收藏）
@MainActor
final class iCloudSyncService: ObservableObject {
    static let shared = iCloudSyncService()
    
    private let store = NSUbiquitousKeyValueStore.default
    
    private init() {
        setupNotifications()
        store.synchronize()
    }
    
    // MARK: - Keys
    private enum Key: String {
        case playlists
        case favorites
        case lastPlayedSongID
        case lastPlaybackTime
    }
    
    // MARK: - Public Methods
    func syncPlaylists(_ playlists: [Playlist]) {
        do {
            let data = try JSONEncoder().encode(playlists)
            store.set(data, forKey: Key.playlists.rawValue)
            store.synchronize()
        } catch {
            print("同步播放列表失败: \(error.localizedDescription)")
        }
    }
    
    func loadPlaylists() -> [Playlist] {
        guard let data = store.data(forKey: Key.playlists.rawValue) else { return [] }
        do {
            return try JSONDecoder().decode([Playlist].self, from: data)
        } catch {
            print("读取播放列表失败: \(error.localizedDescription)")
            return []
        }
    }
    
    func syncFavorites(_ songIDs: [UUID]) {
        let strings = songIDs.map { $0.uuidString }
        store.set(strings, forKey: Key.favorites.rawValue)
        store.synchronize()
    }
    
    func loadFavorites() -> [UUID] {
        let strings = store.array(forKey: Key.favorites.rawValue) as? [String] ?? []
        return strings.compactMap { UUID(uuidString: $0) }
    }
    
    func saveLastPlayed(songID: UUID, time: TimeInterval) {
        store.set(songID.uuidString, forKey: Key.lastPlayedSongID.rawValue)
        store.set(time, forKey: Key.lastPlaybackTime.rawValue)
        store.synchronize()
    }
    
    func loadLastPlayed() -> (UUID?, TimeInterval) {
        let songIDString = store.string(forKey: Key.lastPlayedSongID.rawValue)
        let time = store.double(forKey: Key.lastPlaybackTime.rawValue)
        let songID = songIDString.flatMap { UUID(uuidString: $0) }
        return (songID, time)
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }
    
    @objc private func storeDidChange(_ notification: Notification) {
        store.synchronize()
        // 可以在这里发布通知让 ViewModel 重新加载
        NotificationCenter.default.post(name: .iCloudDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let iCloudDidUpdate = Notification.Name("iCloudDidUpdate")
}
