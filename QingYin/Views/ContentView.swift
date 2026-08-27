//
//  ContentView.swift
//  主入口视图
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        #if targetEnvironment(macCatalyst) || os(macOS)
        MacContentView()
        #elseif os(iOS)
        iOSContentView()
        #else
        MacContentView()
        #endif
    }
}

// MARK: - iOS View
struct iOSContentView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("音乐库", systemImage: "music.note.list")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(1)

            PlaylistView()
                .tabItem {
                    Label("播放列表", systemImage: "list.bullet")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(3)
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                if playerViewModel.currentSong != nil {
                    MiniPlayerView()
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                        .overlay(alignment: .top) {
                            Divider()
                        }
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 49)
                }
            }
        }
        .sheet(isPresented: $playerViewModel.isNowPlayingPresented) {
            NowPlayingView()
        }
    }
}

// MARK: - macOS View
struct MacContentView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedSection: MacSidebarSection = .songs
    
    enum MacSidebarSection: String, CaseIterable, Identifiable {
        case songs = "歌曲"
        case albums = "专辑"
        case artists = "艺术家"
        case favorites = "我喜欢的"
        case playlists = "播放列表"
        case equalizer = "均衡器"
        case settings = "设置"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .songs: return "music.note"
            case .albums: return "square.stack"
            case .artists: return "person"
            case .favorites: return "heart"
            case .playlists: return "list.bullet"
            case .equalizer: return "slider.vertical.3"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 主内容区
            HStack(spacing: 0) {
                // 左侧边栏
                VStack(alignment: .leading, spacing: 0) {
                    Text("清音")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(QingYinColors.ink)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    Text("资料库")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(QingYinColors.inkMist)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    
                    VStack(spacing: 2) {
                        ForEach([MacSidebarSection.songs, .albums, .artists]) { section in
                            MacSidebarItem(
                                icon: section.icon,
                                title: section.rawValue,
                                isSelected: selectedSection == section
                            ) {
                                selectedSection = section
                                if section != .songs {
                                    libraryViewModel.clearFilter()
                                }
                            }
                        }
                    }
                    
                    Text("播放列表")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(QingYinColors.inkMist)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 6)
                    
                    MacSidebarItem(
                        icon: "list.bullet",
                        title: "我的列表",
                        isSelected: selectedSection == .playlists
                    ) {
                        selectedSection = .playlists
                    }
                    
                    Spacer()
                    
                    MacSidebarItem(
                        icon: "heart",
                        title: "我喜欢的",
                        isSelected: selectedSection == .favorites
                    ) {
                        selectedSection = .favorites
                    }
                    .padding(.bottom, 8)

                    MacSidebarItem(
                        icon: "slider.vertical.3",
                        title: "均衡器",
                        isSelected: selectedSection == .equalizer
                    ) {
                        selectedSection = .equalizer
                    }
                    .padding(.bottom, 8)
                    
                    MacSidebarItem(
                        icon: "gearshape",
                        title: "设置",
                        isSelected: selectedSection == .settings
                    ) {
                        selectedSection = .settings
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: 180)
                .background(QingYinColors.porcelainWarm)
                
                // 右侧内容
                VStack(spacing: 0) {
                    selectedContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // 底部播放条
            MacPlayerBar()
        }
        .background(QingYinColors.porcelain)
    }
    
    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .songs:
            MacLibraryView()
        case .albums:
            AlbumListView()
        case .artists:
            ArtistListView()
        case .favorites:
            FavoritesView()
        case .playlists:
            PlaylistView()
        case .equalizer:
            EqualizerView(showsDismissButton: false)
        case .settings:
            SettingsView()
        }
    }
}

struct MacSidebarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? QingYinColors.cobalt : QingYinColors.inkLight)
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? QingYinColors.cobalt : QingYinColors.inkLight)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? QingYinColors.cobaltGhost : Color.clear)
            .cornerRadius(6)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}
