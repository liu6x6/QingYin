//
//  PlaylistView.swift
//  我的播放列表
//

import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedPlaylistID: Playlist.ID?
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""

    private var selectedPlaylist: Playlist? {
        libraryViewModel.playlists.first(where: { $0.id == selectedPlaylistID })
    }

    var body: some View {
        NavigationSplitView {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()

                if libraryViewModel.playlists.isEmpty {
                    PlaylistEmptyState(createAction: { showingCreatePlaylist = true })
                } else {
                    List(libraryViewModel.playlists) { playlist in
                        PlaylistRow(
                            playlist: playlist,
                            isSelected: selectedPlaylistID == playlist.id
                        )
                        .onTapGesture {
                            selectedPlaylistID = playlist.id
                        }
                        .listRowBackground(QingYinColors.porcelain)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("我的列表")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingCreatePlaylist = true }) {
                        Label("新建播放列表", systemImage: "plus")
                    }
                    .foregroundColor(QingYinColors.cobalt)
                }
            }
        } detail: {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()

                if let selectedPlaylist {
                    PlaylistDetailContent(
                        playlist: selectedPlaylist,
                        onDeleted: { selectFirstAvailablePlaylist() }
                    )
                } else {
                    PlaylistSelectionPlaceholder()
                }
            }
        }
        .onAppear {
            selectFirstAvailablePlaylist()
        }
        .onChange(of: libraryViewModel.playlists.map(\.id)) { _ in
            selectFirstAvailablePlaylist()
        }
        .alert("新建播放列表", isPresented: $showingCreatePlaylist) {
            TextField("列表名称", text: $newPlaylistName)
            Button("取消", role: .cancel) {
                newPlaylistName = ""
            }
            Button("创建") {
                if libraryViewModel.createPlaylist(name: newPlaylistName) {
                    newPlaylistName = ""
                    selectedPlaylistID = libraryViewModel.playlists.last?.id
                }
            }
        } message: {
            Text("名称不可为空，且不能与已有列表重复。")
        }
    }

    private func selectFirstAvailablePlaylist() {
        guard selectedPlaylist == nil else { return }
        selectedPlaylistID = libraryViewModel.playlists.first?.id
    }
}

private struct PlaylistRow: View {
    let playlist: Playlist
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(playlistColor)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(QingYinColors.cobalt.opacity(0.55))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(QingYinColors.ink)
                    .lineLimit(1)
                Text("\(playlist.songIDs.count) 首")
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

    private var playlistColor: Color {
        let colors = [
            QingYinColors.cobaltPale,
            QingYinColors.celadonPale,
            QingYinColors.cobaltGhost,
            QingYinColors.celadonLight.opacity(0.3)
        ]
        return colors[abs(playlist.name.hashValue) % colors.count]
    }
}

private struct PlaylistDetailContent: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @State private var showingSongPicker = false
    @State private var showingRename = false
    @State private var playlistName = ""

    let playlist: Playlist
    let onDeleted: () -> Void

    private var songs: [Song] {
        libraryViewModel.songs(in: playlist)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(QingYinColors.cobaltPale)
                        .frame(width: 120, height: 120)
                        .overlay {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 42, weight: .light))
                                .foregroundColor(QingYinColors.cobalt.opacity(0.55))
                        }

                    Text(playlist.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(QingYinColors.ink)
                        .multilineTextAlignment(.center)
                    Text("\(songs.count) 首 · \(formattedPlaylistDuration(songs))")
                        .font(.system(size: 12))
                        .foregroundColor(QingYinColors.inkMist)

                    HStack(spacing: 12) {
                        Button(action: playPlaylist) {
                            Label("播放全部", systemImage: "play.fill")
                        }
                        .buttonStyle(PlaylistActionButtonStyle(isPrimary: true))
                        .disabled(songs.isEmpty)

                        Button(action: shufflePlaylist) {
                            Label("随机播放", systemImage: "shuffle")
                        }
                        .buttonStyle(PlaylistActionButtonStyle(isPrimary: false))
                        .disabled(songs.isEmpty)

                        Button(action: { showingSongPicker = true }) {
                            Label("添加歌曲", systemImage: "plus")
                        }
                        .buttonStyle(PlaylistActionButtonStyle(isPrimary: false))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(QingYinColors.porcelain)
            }

            if songs.isEmpty {
                Section {
                    Text("此列表还没有歌曲。使用“添加歌曲”从音乐库中选择。")
                        .font(.system(size: 13))
                        .foregroundColor(QingYinColors.inkMist)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(QingYinColors.porcelain)
                }
            } else {
                Section {
                    TrackRows(
                        songs: songs,
                        onRemove: { libraryViewModel.removeSong($0, from: playlist) }
                    )
                } header: {
                    Text("曲目")
                        .foregroundColor(QingYinColors.inkMist)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(playlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("重命名", systemImage: "pencil") {
                        playlistName = playlist.name
                        showingRename = true
                    }
                    Button("删除列表", systemImage: "trash", role: .destructive) {
                        libraryViewModel.deletePlaylist(playlist)
                        onDeleted()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSongPicker) {
            PlaylistSongPicker(playlist: playlist)
        }
        .alert("重命名播放列表", isPresented: $showingRename) {
            TextField("列表名称", text: $playlistName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                _ = libraryViewModel.renamePlaylist(playlist, to: playlistName)
            }
        } message: {
            Text("名称不可为空，且不能与已有列表重复。")
        }
    }

    private func playPlaylist() {
        guard let firstSong = songs.first else { return }
        playerViewModel.play(song: firstSong, queue: songs)
    }

    private func shufflePlaylist() {
        let shuffledSongs = songs.shuffled()
        guard let firstSong = shuffledSongs.first else { return }
        playerViewModel.play(song: firstSong, queue: shuffledSongs)
    }
}

private struct PlaylistSongPicker: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID> = []

    let playlist: Playlist

    private var availableSongs: [Song] {
        libraryViewModel.allSongs.filter { !playlist.songIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(availableSongs) { song in
                Button(action: { toggle(song) }) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(QingYinColors.cobaltPale)
                            .frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .foregroundColor(QingYinColors.ink)
                            Text("\(song.artist) · \(song.album)")
                                .font(.system(size: 11))
                                .foregroundColor(QingYinColors.inkMist)
                        }
                        Spacer()
                        Image(systemName: selectedIDs.contains(song.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedIDs.contains(song.id) ? QingYinColors.cobalt : QingYinColors.inkMist)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(QingYinColors.porcelain)
            }
            .scrollContentBackground(.hidden)
            .background(QingYinColors.porcelain)
            .navigationTitle("添加歌曲")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let selectedSongs = libraryViewModel.allSongs.filter { selectedIDs.contains($0.id) }
                        libraryViewModel.addSongsToPlaylist(selectedSongs, playlist: playlist)
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
    }

    private func toggle(_ song: Song) {
        if selectedIDs.contains(song.id) {
            selectedIDs.remove(song.id)
        } else {
            selectedIDs.insert(song.id)
        }
    }
}

private struct PlaylistEmptyState: View {
    let createAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 42, weight: .light))
                .foregroundColor(QingYinColors.cobalt.opacity(0.35))
            Text("还没有播放列表")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(QingYinColors.ink)
            Text("创建一个列表来收藏和整理你的本地音乐。")
                .font(.system(size: 13))
                .foregroundColor(QingYinColors.inkMist)
                .multilineTextAlignment(.center)
            Button("新建播放列表", action: createAction)
                .buttonStyle(PlaylistActionButtonStyle(isPrimary: true))
        }
        .padding()
    }
}

private struct PlaylistSelectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(QingYinColors.cobalt.opacity(0.35))
            Text("选择一个播放列表")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(QingYinColors.ink)
            Text("从左侧列表查看和管理曲目。")
                .font(.system(size: 13))
                .foregroundColor(QingYinColors.inkMist)
        }
    }
}

private struct PlaylistActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isPrimary ? QingYinColors.porcelain : QingYinColors.cobalt)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isPrimary ? QingYinColors.cobalt : QingYinColors.porcelainDeep)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private func formattedPlaylistDuration(_ songs: [Song]) -> String {
    let totalSeconds = max(0, Int(songs.reduce(0) { $0 + $1.duration }))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    return hours > 0 ? "\(hours) 小时 \(minutes) 分钟" : "\(minutes) 分钟"
}
