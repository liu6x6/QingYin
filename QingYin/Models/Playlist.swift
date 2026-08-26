//
//  Playlist.swift
//  播放列表数据模型
//

import Foundation

struct Playlist: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var songIDs: [UUID]
    var createdAt: Date
    
    init(id: UUID? = nil, name: String, songIDs: [UUID] = [], createdAt: Date = Date()) {
        self.id = id ?? Song.stableID(from: "playlist:\(name)")
        self.name = name
        self.songIDs = songIDs
        self.createdAt = createdAt
    }
    
    mutating func addSong(_ song: Song) {
        guard !songIDs.contains(song.id) else { return }
        songIDs.append(song.id)
    }
    
    mutating func removeSong(_ song: Song) {
        songIDs.removeAll { $0 == song.id }
    }
}

#if DEBUG
extension Playlist {
    static let samplePlaylists: [Playlist] = [
        Playlist(name: "深夜独处", songIDs: []),
        Playlist(name: "工作专注", songIDs: []),
        Playlist(name: "运动节奏", songIDs: []),
        Playlist(name: "周末放松", songIDs: [])
    ]
}
#endif
