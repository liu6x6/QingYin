//
//  SearchView.swift
//  搜索页面
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @State private var searchText = ""
    
    var filteredSongs: [Song] {
        if searchText.isEmpty { return [] }
        return libraryViewModel.songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            QingYinColors.porcelain.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 搜索栏
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(QingYinColors.inkMist)
                    TextField("搜索歌曲、艺术家...", text: $searchText)
                        .font(.system(size: 14))
                }
                .padding(10)
                .background(QingYinColors.porcelain)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
                )
                .padding(16)
                
                if searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(QingYinColors.cobalt.opacity(0.3))
                        Text("搜索你的音乐")
                            .font(.system(size: 14))
                            .foregroundColor(QingYinColors.inkMist)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredSongs) { song in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(QingYinColors.cobaltPale)
                                    .frame(width: 44, height: 44)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 15))
                                        .foregroundColor(QingYinColors.ink)
                                    Text("\(song.artist) · \(song.album)")
                                        .font(.system(size: 12))
                                        .foregroundColor(QingYinColors.inkMist)
                                }
                                
                                Spacer()
                                
                                Text(song.formattedDuration)
                                    .font(.system(size: 12))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                            .listRowBackground(QingYinColors.porcelain)
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                playerViewModel.play(song: song, queue: libraryViewModel.songs)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(QingYinColors.porcelain)
                }
            }
        }
    }
}
