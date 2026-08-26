//
//  MusicLibraryService.swift
//  系统音乐库访问
//

import Foundation
import Combine

#if os(iOS)
import MediaPlayer
#endif

enum LibraryAuthorizationStatus {
    case notDetermined
    case denied
    case authorized
}

@MainActor
final class MusicLibraryService: ObservableObject {
    static let shared = MusicLibraryService()
    
    @Published var authorizationStatus: LibraryAuthorizationStatus = .notDetermined
    @Published var songs: [Song] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Authorization
    func requestAuthorization() {
        #if os(iOS)
        requestIOSAuthorization()
        #else
        // macOS 直接允许，然后开始扫描 Apple Music 本地文件
        authorizationStatus = .authorized
        loadSystemLibrary()
        #endif
    }
    
    #if os(iOS)
    private func requestIOSAuthorization() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.authorizationStatus = .authorized
                    self?.loadSystemLibrary()
                case .denied, .restricted:
                    self?.authorizationStatus = .denied
                    self?.errorMessage = "需要访问音乐库权限"
                case .notDetermined:
                    self?.authorizationStatus = .notDetermined
                @unknown default:
                    self?.authorizationStatus = .denied
                }
            }
        }
    }
    #endif
    
    // MARK: - Load Library
    func loadSystemLibrary() {
        #if os(iOS)
        loadIOSLibrary()
        #else
        loadMacOSLibrary()
        #endif
    }
    
    #if os(macOS)
    private func loadMacOSLibrary() {
        isLoading = true
        let appleMusicSongs = AppleMusicMacService.shared.scanAppleMusicLibrary()
        songs = appleMusicSongs
        if !appleMusicSongs.isEmpty {
            AppleMusicMacService.shared.cacheLibrary(appleMusicSongs)
        }
        isLoading = false
    }

    func restoreCachedMacOSLibrary() {
        songs = AppleMusicMacService.shared.restoreCachedLibrary()
    }
    #endif
    
    #if os(iOS)
    private func loadIOSLibrary() {
        isLoading = true
        
        let query = MPMediaQuery.songs()
        guard let mediaItems = query.items else {
            isLoading = false
            return
        }
        
        var loadedSongs: [Song] = []
        for item in mediaItems {
            let song = Song(
                id: Song.stableID(from: "media:\(item.persistentID)"),
                title: item.title ?? "未知歌曲",
                artist: item.artist ?? "未知艺术家",
                album: item.albumTitle ?? "",
                duration: item.playbackDuration,
                assetURL: item.assetURL,
                lyrics: nil,
                artworkImage: nil
            )
            loadedSongs.append(song)
        }
        
        songs = loadedSongs
        isLoading = false
    }
    #endif
}
