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
    private let tabBarHeight: CGFloat = 60

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    LibraryView()
                        .tag(0)

                    SearchView()
                        .tag(1)

                    PlaylistView()
                        .tag(2)

                    SettingsView()
                        .tag(3)
                }
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(
                        height: playerViewModel.currentSong == nil
                            ? tabBarHeight + 24
                            : tabBarHeight + 96
                    )
                }

                if playerViewModel.currentSong != nil {
                    MiniPlayerView()
                        .padding(.horizontal, 12)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + tabBarHeight + 20)
                }

                iOSGlassTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 12)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 8)
            }
        }
        .sheet(isPresented: $playerViewModel.isNowPlayingPresented) {
            NowPlayingView()
        }
    }
}

private struct iOSGlassTabBar: View {
    @Binding var selectedTab: Int

    private let tabs = [
        (id: 0, title: "音乐库", icon: "music.note.list"),
        (id: 1, title: "搜索", icon: "magnifyingglass"),
        (id: 2, title: "播放列表", icon: "list.bullet"),
        (id: 3, title: "设置", icon: "gearshape")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    selectedTab = tab.id
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(
                        selectedTab == tab.id
                            ? QingYinColors.cobalt
                            : QingYinColors.inkLight
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab.id ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .background {
            glassCapsule
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: QingYinColors.ink.opacity(0.10), radius: 14, y: 5)
    }

    @ViewBuilder
    private var glassCapsule: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(Color.clear)
                .glassEffect()
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
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
