//
//  PlaylistView.swift
//  播放列表页面
//

import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var showingAddPlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        ZStack {
            QingYinColors.porcelain.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("播放列表")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(QingYinColors.ink)
                    
                    Spacer()
                    
                    Button(action: { showingAddPlaylist = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(QingYinColors.cobalt)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // 播放列表网格
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(libraryViewModel.playlists) { playlist in
                            PlaylistCard(playlist: playlist)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // 最近播放
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最近播放")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(QingYinColors.ink)
                            Spacer()
                            Text("查看全部")
                                .font(.system(size: 12))
                                .foregroundColor(QingYinColors.celadon)
                        }
                        
                        ForEach(libraryViewModel.songs.prefix(3)) { song in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(QingYinColors.cobaltPale)
                                    .frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 13))
                                        .foregroundColor(QingYinColors.ink)
                                    Text(song.artist)
                                        .font(.system(size: 11))
                                        .foregroundColor(QingYinColors.inkMist)
                                }
                                Spacer()
                                Text(song.formattedDuration)
                                    .font(.system(size: 11))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .alert("新建播放列表", isPresented: $showingAddPlaylist) {
            TextField("列表名称", text: $newPlaylistName)
            Button("取消", role: .cancel) {}
            Button("创建") {
                if !newPlaylistName.isEmpty {
                    libraryViewModel.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        } message: {
            Text("输入播放列表名称")
        }
    }
}

struct PlaylistCard: View {
    let playlist: Playlist
    
    private var colors: [Color] {
        [QingYinColors.cobaltPale, QingYinColors.celadonPale, QingYinColors.cobaltGhost, QingYinColors.celadonLight.opacity(0.3)]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(colors[abs(playlist.name.hashValue) % colors.count])
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(QingYinColors.cobalt.opacity(0.08), lineWidth: 1)
                )
            
            Text(playlist.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(QingYinColors.ink)
            
            Text("\(playlist.songIDs.count) 首")
                .font(.system(size: 11))
                .foregroundColor(QingYinColors.inkMist)
        }
    }
}
