//
//  AlbumListView.swift
//  专辑列表
//

import SwiftUI

struct AlbumListView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        ZStack {
            QingYinColors.porcelain.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("专辑")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(QingYinColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                List {
                    ForEach(libraryViewModel.albums, id: \.self) { album in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(QingYinColors.cobaltPale)
                                .frame(width: 56, height: 56)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(QingYinColors.ink)
                                Text("\(libraryViewModel.songs(forAlbum: album).count) 首")
                                    .font(.system(size: 12))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                        }
                        .listRowBackground(QingYinColors.porcelain)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .background(QingYinColors.porcelain)
            }
        }
    }
}

struct ArtistListView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        ZStack {
            QingYinColors.porcelain.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("艺术家")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(QingYinColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                List {
                    ForEach(libraryViewModel.artists, id: \.self) { artist in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(QingYinColors.celadonPale)
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text(String(artist.prefix(1)))
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(QingYinColors.celadon)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(QingYinColors.ink)
                                Text("\(libraryViewModel.songs(forArtist: artist).count) 首")
                                    .font(.system(size: 12))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                        }
                        .listRowBackground(QingYinColors.porcelain)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .background(QingYinColors.porcelain)
            }
        }
    }
}
