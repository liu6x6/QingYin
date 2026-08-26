//
//  AlbumListView.swift
//  专辑与艺术家浏览
//

import SwiftUI

struct AlbumListView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedAlbumID: MusicAlbum.ID?

    let showsTitle: Bool

    init(showsTitle: Bool = true) {
        self.showsTitle = showsTitle
    }

    private var albums: [MusicAlbum] {
        let query = libraryViewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return libraryViewModel.libraryAlbums }
        return libraryViewModel.libraryAlbums.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()

                if albums.isEmpty {
                    AlbumEmptyState()
                } else {
                    List(albums, selection: $selectedAlbumID) { album in
                        AlbumRow(album: album)
                            .tag(album.id)
                            .listRowBackground(QingYinColors.porcelain)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(showsTitle ? "专辑" : "")
        } detail: {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()

                if let selectedAlbum {
                    AlbumDetailContent(album: selectedAlbum)
                } else {
                    AlbumSelectionPlaceholder()
                }
            }
        }
        .onAppear {
            selectFirstAvailableAlbum()
        }
        .onChange(of: albums.map(\.id)) { _ in
            selectFirstAvailableAlbum()
        }
    }

    private var selectedAlbum: MusicAlbum? {
        albums.first(where: { $0.id == selectedAlbumID })
    }

    private func selectFirstAvailableAlbum() {
        guard selectedAlbum == nil else { return }
        selectedAlbumID = albums.first?.id
    }
}

private struct AlbumRow: View {
    let album: MusicAlbum

    var body: some View {
        HStack(spacing: 12) {
            AlbumArtwork(album: album, size: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(QingYinColors.ink)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.system(size: 12))
                    .foregroundColor(QingYinColors.celadon)
                    .lineLimit(1)
                Text("\(album.songCount) 首 · \(formattedDuration(album.totalDuration))")
                    .font(.system(size: 11))
                    .foregroundColor(QingYinColors.inkMist)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

}

private struct AlbumDetailContent: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    let album: MusicAlbum

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    AlbumArtwork(album: album, size: 152)

                    VStack(spacing: 4) {
                        Text(album.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(QingYinColors.ink)
                            .multilineTextAlignment(.center)
                        Text(album.artist)
                            .font(.system(size: 15))
                            .foregroundColor(QingYinColors.celadon)
                        Text("\(album.songCount) 首 · \(formattedDuration(album.totalDuration))")
                            .font(.system(size: 12))
                            .foregroundColor(QingYinColors.inkMist)
                    }

                    HStack(spacing: 12) {
                        Button(action: playAlbum) {
                            Label("播放全部", systemImage: "play.fill")
                        }
                        .buttonStyle(AlbumActionButtonStyle(isPrimary: true))

                        Button(action: shuffleAlbum) {
                            Label("随机播放", systemImage: "shuffle")
                        }
                        .buttonStyle(AlbumActionButtonStyle(isPrimary: false))
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(QingYinColors.porcelain)
            }

            Section {
                TrackRows(songs: album.songs)
            } header: {
                Text("曲目")
                    .foregroundColor(QingYinColors.inkMist)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(album.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func playAlbum() {
        guard let firstSong = album.songs.first else { return }
        playerViewModel.play(song: firstSong, queue: album.songs)
    }

    private func shuffleAlbum() {
        let shuffledSongs = album.songs.shuffled()
        guard let firstSong = shuffledSongs.first else { return }
        playerViewModel.play(song: firstSong, queue: shuffledSongs)
    }

}

private struct AlbumSelectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(QingYinColors.cobalt.opacity(0.3))
            Text("选择一张专辑")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(QingYinColors.ink)
            Text("从左侧列表查看专辑详情和曲目。")
                .font(.system(size: 13))
                .foregroundColor(QingYinColors.inkMist)
        }
    }
}

private struct AlbumEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(QingYinColors.cobalt.opacity(0.3))
            Text("没有找到专辑")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(QingYinColors.ink)
            Text("导入带有专辑信息的本地音乐后会显示在这里。")
                .font(.system(size: 13))
                .foregroundColor(QingYinColors.inkMist)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

private struct AlbumArtwork: View {
    let album: MusicAlbum
    let size: CGFloat

    var body: some View {
        ZStack {
            if let artwork = album.artwork {
                artwork
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(QingYinColors.cobaltPale)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.32, weight: .light))
                            .foregroundColor(QingYinColors.cobalt.opacity(0.45))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.12)
                .stroke(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct AlbumActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isPrimary ? QingYinColors.porcelain : QingYinColors.cobalt)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isPrimary ? QingYinColors.cobalt : QingYinColors.porcelainDeep)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ArtistListView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedArtistID: MusicArtist.ID?

    let showsTitle: Bool

    init(showsTitle: Bool = true) {
        self.showsTitle = showsTitle
    }

    var body: some View {
        NavigationSplitView {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()

                if artists.isEmpty {
                    ArtistEmptyState()
                } else {
                    List(artists, selection: $selectedArtistID) { artist in
                        ArtistRow(
                            artist: artist,
                            isSelected: selectedArtistID == artist.id
                        )
                            .tag(artist.id)
                            .onTapGesture {
                                selectedArtistID = artist.id
                            }
                            .listRowBackground(QingYinColors.porcelain)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(showsTitle ? "艺术家" : "")
        } detail: {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()

                if let selectedArtist {
                    ArtistDetailContent(artist: selectedArtist)
                } else {
                    ArtistSelectionPlaceholder()
                }
            }
        }
        .onAppear {
            selectFirstAvailableArtist()
        }
        .onChange(of: artists.map(\.id)) { _ in
            selectFirstAvailableArtist()
        }
    }

    private var artists: [MusicArtist] {
        let query = libraryViewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return libraryViewModel.libraryArtists }
        return libraryViewModel.libraryArtists.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedArtist: MusicArtist? {
        artists.first(where: { $0.id == selectedArtistID })
    }

    private func selectFirstAvailableArtist() {
        guard selectedArtist == nil else { return }
        selectedArtistID = artists.first?.id
    }
}

private struct ArtistRow: View {
    let artist: MusicArtist
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtistArtwork(artist: artist.name, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(artist.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(QingYinColors.ink)
                    .lineLimit(1)
                Text("\(artist.albums.count) 张专辑 · \(artist.songCount) 首")
                    .font(.system(size: 11))
                    .foregroundColor(QingYinColors.inkMist)
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? QingYinColors.cobaltGhost : Color.clear)
        )
    }
}

private struct ArtistDetailContent: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    let artist: MusicArtist

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ArtistArtwork(artist: artist.name, size: 152)
                    Text(artist.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(QingYinColors.ink)
                    Text("\(artist.albums.count) 张专辑 · \(artist.songCount) 首 · \(formattedDuration(artist.totalDuration))")
                        .font(.system(size: 12))
                        .foregroundColor(QingYinColors.inkMist)

                    HStack(spacing: 12) {
                        Button(action: playArtist) {
                            Label("播放全部", systemImage: "play.fill")
                        }
                        .buttonStyle(AlbumActionButtonStyle(isPrimary: true))

                        Button(action: shuffleArtist) {
                            Label("随机播放", systemImage: "shuffle")
                        }
                        .buttonStyle(AlbumActionButtonStyle(isPrimary: false))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(QingYinColors.porcelain)
            }

            if !artist.albums.isEmpty {
                Section {
                    ForEach(artist.albums) { album in
                        HStack(spacing: 12) {
                            AlbumArtwork(album: album, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(QingYinColors.ink)
                                Text("\(album.songCount) 首 · \(formattedDuration(album.totalDuration))")
                                    .font(.system(size: 11))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                            Spacer()
                        }
                        .listRowBackground(QingYinColors.porcelain)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("专辑")
                        .foregroundColor(QingYinColors.inkMist)
                }
            }

            Section {
                TrackRows(songs: artist.songs)
            } header: {
                Text("曲目")
                    .foregroundColor(QingYinColors.inkMist)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(artist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func playArtist() {
        guard let firstSong = artist.songs.first else { return }
        playerViewModel.play(song: firstSong, queue: artist.songs)
    }

    private func shuffleArtist() {
        let shuffledSongs = artist.songs.shuffled()
        guard let firstSong = shuffledSongs.first else { return }
        playerViewModel.play(song: firstSong, queue: shuffledSongs)
    }
}

struct TrackRows: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @State private var selectedSongID: Song.ID?

    let songs: [Song]
    let onRemove: ((Song) -> Void)?

    init(songs: [Song], onRemove: ((Song) -> Void)? = nil) {
        self.songs = songs
        self.onRemove = onRemove
    }

    var body: some View {
        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
            HStack(spacing: 14) {
                Text("\(index + 1)")
                    .font(.system(size: 13))
                    .foregroundColor(QingYinColors.inkMist)
                    .frame(width: 24, alignment: .trailing)
                SongRow(song: song)
                Button(action: { toggleTrackPlayback(song) }) {
                    Image(systemName: isTrackPlaying(song) ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(QingYinColors.cobalt)
                        .frame(width: 30, height: 30)
                        .background(QingYinColors.cobaltGhost)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help(isTrackPlaying(song) ? "暂停" : "播放")
                if let onRemove {
                    Button(action: { onRemove(song) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(QingYinColors.inkMist)
                            .frame(width: 28, height: 30)
                    }
                    .buttonStyle(.borderless)
                    .help("从列表移除")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            #if os(macOS)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedSongID == song.id ? QingYinColors.cobaltGhost : Color.clear)
            )
            .onTapGesture {
                selectedSongID = song.id
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    selectedSongID = song.id
                    playerViewModel.play(song: song, queue: songs)
                }
            )
            #else
            .onTapGesture {
                playerViewModel.play(song: song, queue: songs)
            }
            #endif
            .listRowBackground(QingYinColors.porcelain)
            .listRowSeparator(.hidden)
        }
    }

    private func isTrackPlaying(_ song: Song) -> Bool {
        playerViewModel.currentSong?.id == song.id && playerViewModel.isPlaying
    }

    private func toggleTrackPlayback(_ song: Song) {
        if playerViewModel.currentSong?.id == song.id {
            playerViewModel.togglePlayPause()
        } else {
            playerViewModel.play(song: song, queue: songs)
        }
    }
}

private struct ArtistArtwork: View {
    let artist: String
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(QingYinColors.celadonPale)
            .frame(width: size, height: size)
            .overlay(
                Text(String(artist.prefix(1)))
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundColor(QingYinColors.celadon)
            )
    }
}

private struct ArtistSelectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(QingYinColors.celadon.opacity(0.4))
            Text("选择一位艺术家")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(QingYinColors.ink)
            Text("从左侧列表查看艺术家的专辑和曲目。")
                .font(.system(size: 13))
                .foregroundColor(QingYinColors.inkMist)
        }
    }
}

private struct ArtistEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(QingYinColors.celadon.opacity(0.4))
            Text("没有找到艺术家")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(QingYinColors.ink)
        }
    }
}

private func formattedDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = max(0, Int(duration))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    return hours > 0 ? "\(hours) 小时 \(minutes) 分钟" : "\(minutes) 分钟"
}
