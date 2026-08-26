//
//  LibraryView.swift
//  音乐库页面
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @State private var showingFileImporter = false
    
    var body: some View {
        ZStack {
            QingYinColors.porcelain.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 搜索栏 + 筛选 + 导入
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(QingYinColors.inkMist)
                        TextField("搜索歌曲、艺术家、专辑...", text: $libraryViewModel.searchText)
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(QingYinColors.porcelain)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    
                    HStack(spacing: 8) {
                        ForEach(LibraryViewModel.LibraryFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: libraryViewModel.selectedFilter == filter
                            ) {
                                libraryViewModel.selectedFilter = filter
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { showingFileImporter = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                Text("导入")
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundColor(QingYinColors.cobalt)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(QingYinColors.cobalt.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(QingYinColors.porcelainWarm)
                
                // 迷你播放器
                MiniPlayerView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                switch libraryViewModel.selectedFilter {
                case .songs:
                    List {
                        ForEach(libraryViewModel.filteredSongs) { song in
                            SongRow(song: song)
                                .listRowBackground(QingYinColors.porcelain)
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    playerViewModel.play(song: song, queue: libraryViewModel.filteredSongs)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .background(QingYinColors.porcelain)
                case .albums:
                    AlbumListView(showsTitle: false)
                case .artists:
                    ArtistListView(showsTitle: false)
                }
            }
        }
        .sheet(isPresented: $playerViewModel.isNowPlayingPresented) {
            NowPlayingView()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: LocalFileService.supportedContentTypes,
            allowsMultipleSelection: true,
            onCompletion: { result in
                switch result {
                case .success(let urls):
                    let newSongs = libraryViewModel.importAudioFiles(from: urls)
                    if newSongs.count == 1, let song = newSongs.first {
                        playerViewModel.play(song: song, queue: libraryViewModel.filteredSongs)
                    }
                case .failure(let error):
                    print("导入失败: \(error.localizedDescription)")
                }
            }
        )
    }
}

// MARK: - Song Row
struct SongRow: View {
    let song: Song
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var isPlaying: Bool {
        playerViewModel.currentSong?.id == song.id && playerViewModel.isPlaying
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(songArtColor)
                    .frame(width: 44, height: 44)
                
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
                    .frame(width: 44, height: 44)
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 15, weight: isPlaying ? .semibold : .regular))
                    .foregroundColor(isPlaying ? QingYinColors.cobalt : QingYinColors.ink)
                
                Text("\(song.artist) · \(song.album)")
                    .font(.system(size: 12))
                    .foregroundColor(QingYinColors.inkMist)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 播放状态
            if isPlaying {
                HStack(spacing: 2) {
                    ForEach(0..<4) { index in
                        EQBar(index: index)
                    }
                }
            } else {
                Text(song.formattedDuration)
                    .font(.system(size: 12))
                    .foregroundColor(QingYinColors.inkMist)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Menu {
                if libraryViewModel.playlists.isEmpty {
                    Text("请先新建播放列表")
                } else {
                    ForEach(libraryViewModel.playlists) { playlist in
                        Button(playlist.name) {
                            libraryViewModel.addSongsToPlaylist([song], playlist: playlist)
                        }
                    }
                }
            } label: {
                Label("添加到播放列表", systemImage: "text.badge.plus")
            }
        }
    }
    
    private var songArtColor: Color {
        let colors: [Color] = [
            QingYinColors.cobaltPale,
            QingYinColors.celadonPale,
            QingYinColors.cobaltGhost,
            QingYinColors.celadonLight.opacity(0.3),
            QingYinColors.cobaltLight.opacity(0.15),
            QingYinColors.celadon.opacity(0.2)
        ]
        return colors[abs(song.title.hashValue) % colors.count]
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? QingYinColors.cobalt : Color.clear)
                .foregroundColor(isSelected ? Color.white : QingYinColors.inkLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? QingYinColors.cobalt : QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
                )
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EQ Bar
struct EQBar: View {
    let index: Int
    @State private var height: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(QingYinColors.cobalt)
            .frame(width: 2, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.15)) {
                    height = CGFloat.random(in: 10...16)
                }
            }
    }
}
