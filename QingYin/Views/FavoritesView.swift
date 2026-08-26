//
//  FavoritesView.swift
//  收藏歌曲视图
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    
    var favoriteSongs: [Song] {
        libraryViewModel.allSongs.filter { libraryViewModel.isFavorite($0) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("我喜欢的歌曲")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(QingYinColors.ink)
                Spacer()
                Text("\(favoriteSongs.count) 首")
                    .font(.system(size: 12))
                    .foregroundColor(QingYinColors.inkMist)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if favoriteSongs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(QingYinColors.cobalt.opacity(0.3))
                    Text("还没有收藏的歌曲")
                        .font(.system(size: 14))
                        .foregroundColor(QingYinColors.inkMist)
                }
                Spacer()
            } else {
                List {
                    ForEach(favoriteSongs) { song in
                        SongRow(song: song)
                            .listRowBackground(QingYinColors.porcelain)
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                playerViewModel.play(song: song, queue: favoriteSongs)
                            }
                    }
                }
                .listStyle(.plain)
                .background(QingYinColors.porcelain)
            }
        }
    }
}
