//
//  LibraryViewModel.swift
//  音乐库视图模型
//

import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var playlists: [Playlist] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: LibraryFilter = .songs
    @Published var isAuthorized: Bool = false
    @Published var favoriteIDs: Set<UUID> = []
    @Published var sortKey: SortKey = .none
    @Published var sortAscending: Bool = true
    
    enum SortKey: String, CaseIterable {
        case none
        case title
        case artist
        case album
        case duration
        
        var displayName: String {
            switch self {
            case .none: return "默认"
            case .title: return "标题"
            case .artist: return "艺术家"
            case .album: return "专辑"
            case .duration: return "时长"
            }
        }
    }
    
    private let libraryService = MusicLibraryService.shared
    private let localFileService = LocalFileService.shared
    private let iCloud = iCloudSyncService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private enum PersistenceKey: String {
        case favoriteIDs = "qingyin.favoriteIDs"
        case playlists = "qingyin.playlists"
    }
    
    enum LibraryFilter: String, CaseIterable {
        case songs = "歌曲"
        case albums = "专辑"
        case artists = "艺术家"
    }
    
    init() {
        setupBindings()
        loadSampleData()
        restoreFavorites()
        restoreLocalPlaylists()
        
        // 监听 favoriteIDs 变化，自动持久化
        $favoriteIDs
            .dropFirst()
            .sink { [weak self] ids in
                self?.saveFavorites(ids)
            }
            .store(in: &cancellables)
    }
    
    private func setupBindings() {
        libraryService.$songs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] songs in
                self?.songs = songs
            }
            .store(in: &cancellables)
        
        libraryService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isAuthorized = status == .authorized
            }
            .store(in: &cancellables)
        
        localFileService.$importedSongs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func requestLibraryAccess() {
        libraryService.requestAuthorization()
    }
    
    // MARK: - Local Files
    /// 导入音频文件，返回新导入的歌曲（已去重）
    func importAudioFiles(from urls: [URL]) -> [Song] {
        let imported = localFileService.importAudioFiles(from: urls)
        
        // 去重：过滤掉已在列表中的歌曲（按 ID）
        let existingIDs = Set(allSongs.map { $0.id })
        let newSongs = imported.filter { !existingIDs.contains($0.id) }
        
        return newSongs
    }
    
    var allSongs: [Song] {
        // 优先显示本地导入 + 系统库 + 示例
        var combined = songs
        if !libraryService.songs.isEmpty {
            combined.append(contentsOf: libraryService.songs)
        }
        if !localFileService.importedSongs.isEmpty {
            combined.append(contentsOf: localFileService.importedSongs)
        }
        // 去重：相同 ID 或相同文件路径只保留一个
        if !combined.isEmpty {
            var seenIDs: Set<UUID> = []
            var seenURLs: Set<String> = []
            combined = combined.filter { song in
                // 按 ID 去重（稳定 ID 保证同一文件始终一致）
                if seenIDs.contains(song.id) { return false }
                seenIDs.insert(song.id)
                // 按路径去重（兼容无 assetURL 的歌曲）
                if let url = song.assetURL {
                    let path = url.path
                    if seenURLs.contains(path) { return false }
                    seenURLs.insert(path)
                }
                return true
            }
        }
        
        // 应用筛选
        switch activeFilter {
        case .all:
            break
        case .album(let name):
            combined = combined.filter { $0.album == name }
        case .artist(let name):
            combined = combined.filter { $0.artist == name }
        }
        
        return combined.isEmpty ? songs : combined
    }
    
    var filteredSongs: [Song] {
        let source = allSongs
        let filtered: [Song]
        if searchText.isEmpty {
            filtered = source
        } else {
            filtered = source.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText) ||
                $0.album.localizedCaseInsensitiveContains(searchText)
            }
        }
        return sorted(filtered)
    }
    
    private func sorted(_ songs: [Song]) -> [Song] {
        switch sortKey {
        case .none:
            return songs
        case .title:
            return songs.sorted { sortAscending ? $0.title < $1.title : $0.title > $1.title }
        case .artist:
            return songs.sorted { sortAscending ? $0.artist < $1.artist : $0.artist > $1.artist }
        case .album:
            return songs.sorted { sortAscending ? $0.album < $1.album : $0.album > $1.album }
        case .duration:
            return songs.sorted { sortAscending ? $0.duration < $1.duration : $0.duration > $1.duration }
        }
    }
    
    func toggleSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
    }
    
    var albums: [String] {
        Array(Set(allSongs.map { $0.album })).filter { !$0.isEmpty }.sorted()
    }
    
    var artists: [String] {
        Array(Set(allSongs.map { $0.artist })).sorted()
    }
    
    func songs(forAlbum album: String) -> [Song] {
        allSongs.filter { $0.album == album }
    }
    
    func songs(forArtist artist: String) -> [Song] {
        allSongs.filter { $0.artist == artist }
    }
    
    func createPlaylist(name: String) {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        savePlaylists()
    }
    
    func updatePlaylists(_ newPlaylists: [Playlist]) {
        playlists = newPlaylists
        savePlaylists()
    }
    
    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: PersistenceKey.playlists.rawValue)
        }
        iCloud.syncPlaylists(playlists)
    }
    
    private func restoreLocalPlaylists() {
        if let data = UserDefaults.standard.data(forKey: PersistenceKey.playlists.rawValue),
           let restored = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = restored
            return
        }
        // 回退到 iCloud
        let synced = iCloud.loadPlaylists()
        if !synced.isEmpty {
            playlists = synced
        }
    }
    
    func restoreFromiCloud() {
        let synced = iCloud.loadPlaylists()
        if !synced.isEmpty {
            playlists = synced
            savePlaylists()
        }
    }
    
    // MARK: - Favorites
    func isFavorite(_ song: Song) -> Bool {
        favoriteIDs.contains(song.id)
    }
    
    func toggleFavorite(_ song: Song) {
        if favoriteIDs.contains(song.id) {
            favoriteIDs.remove(song.id)
        } else {
            favoriteIDs.insert(song.id)
        }
    }
    
    func restoreFavorites() {
        // 优先从本地 UserDefaults 恢复
        if let data = UserDefaults.standard.data(forKey: PersistenceKey.favoriteIDs.rawValue),
           let strings = try? JSONDecoder().decode([String].self, from: data) {
            let ids = strings.compactMap { UUID(uuidString: $0) }
            if !ids.isEmpty {
                favoriteIDs = Set(ids)
                return
            }
        }
        // 回退到 iCloud
        let ids = iCloud.loadFavorites()
        if !ids.isEmpty {
            favoriteIDs = Set(ids)
        }
    }
    
    private func saveFavorites(_ ids: Set<UUID>) {
        let strings = ids.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(strings) {
            UserDefaults.standard.set(data, forKey: PersistenceKey.favoriteIDs.rawValue)
        }
        iCloud.syncFavorites(Array(ids))
    }
    
    // MARK: - Delete
    func deleteSong(_ song: Song) {
        LocalFileService.shared.deleteImportedSong(song)
    }
    
    func canDelete(_ song: Song) -> Bool {
        return song.assetURL != nil
    }
    
    // MARK: - Filter
    @Published var activeFilter: FilterType = .all
    
    enum FilterType: Equatable {
        case all
        case album(String)
        case artist(String)
        
        var displayName: String {
            switch self {
            case .all: return "全部"
            case .album(let name): return "专辑: \(name)"
            case .artist(let name): return "艺术家: \(name)"
            }
        }
    }
    
    func filterByAlbum(_ album: String) {
        activeFilter = .album(album)
        searchText = ""
    }
    
    func filterByArtist(_ artist: String) {
        activeFilter = .artist(artist)
        searchText = ""
    }
    
    func clearFilter() {
        activeFilter = .all
    }
    
    // MARK: - Add to Queue
    func playNext(_ song: Song) {
        AudioPlayerManager.shared.addToQueueNext(song)
    }
    
    // MARK: - Batch Operations
    func deleteSongs(_ songs: [Song]) {
        for song in songs {
            deleteSong(song)
        }
    }
    
    func addSongsToPlaylist(_ songs: [Song], playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            for song in songs {
                playlists[index].addSong(song)
            }
            savePlaylists()
        }
    }
    
    // MARK: - Sample Data
    private func loadSampleData() {
        #if DEBUG
        songs = Song.sampleSongs
        playlists = Playlist.samplePlaylists
        #endif
    }
}
