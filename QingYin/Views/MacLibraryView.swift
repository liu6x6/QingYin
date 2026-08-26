//
//  MacLibraryView.swift
//  macOS 音乐库视图
//

import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit

struct MacLibraryView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var showingFileImporter = false
    @State private var selectedSongIDs: Set<UUID> = []
    @State private var showingAddToPlaylist = false
    @State private var isDropTargeted = false
    
    // 列顺序
    @State private var columnOrder: [Column]
    
    // 列宽
    @State private var columnWidths: [Column: CGFloat]
    
    // 正在拖拽的列分隔线
    @State private var resizingColumn: Column?
    @State private var resizeStartX: CGFloat = 0
    @State private var resizeStartWidth: CGFloat = 0
    
    // 拖拽列排序
    @State private var draggingColumn: Column?
    @State private var dragStartX: CGFloat = 0
    
    enum Column: String, CaseIterable, Identifiable {
        case index = "#"
        case title = "标题"
        case artist = "艺术家"
        case album = "专辑"
        case duration = "时长"
        case favorite = "喜欢"
        
        var id: String { rawValue }
        var isResizable: Bool { self != .favorite }
        /// 弹性列：吸收剩余空间
        var isFlexible: Bool { self == .title }
    }
    
    /// 根据可用宽度计算实际列宽，弹性列吸收剩余空间
    private func effectiveColumnWidths(totalWidth: CGFloat) -> [Column: CGFloat] {
        let padding: CGFloat = 32  // 左右各 16pt
        let available = totalWidth - padding
        let fixedTotal = columnOrder.reduce(CGFloat(0)) { sum, col in
            sum + (col.isFlexible ? 0 : (columnWidths[col] ?? 80))
        }
        let remaining = max(80, available - fixedTotal)
        var result = columnWidths
        if let flexCol = columnOrder.first(where: { $0.isFlexible }) {
            result[flexCol] = remaining
        }
        return result
    }
    
    init() {
        let savedOrder = UserDefaults.standard.array(forKey: "macLibraryColumnOrder") as? [String]
        let savedWidths = UserDefaults.standard.dictionary(forKey: "macLibraryColumnWidths") as? [String: CGFloat]
        
        _columnOrder = State(initialValue: savedOrder?.compactMap { Column(rawValue: $0) } ?? Column.allCases)
        _columnWidths = State(initialValue: [
            .index: 40,
            .title: 280,
            .artist: 140,
            .album: 180,
            .duration: 70,
            .favorite: 50
        ])
        
        // 恢复保存的列宽
        if let savedWidths = savedWidths {
            for (key, value) in savedWidths {
                if let column = Column(rawValue: key) {
                    _columnWidths.wrappedValue[column] = value
                }
            }
        }
    }
    
    private func saveColumnSettings() {
        UserDefaults.standard.set(columnOrder.map { $0.rawValue }, forKey: "macLibraryColumnOrder")
        let widths = columnWidths.mapKeys { $0.rawValue }
        UserDefaults.standard.set(widths, forKey: "macLibraryColumnWidths")
    }
    
    var selectedSongs: [Song] {
        libraryViewModel.filteredSongs.filter { selectedSongIDs.contains($0.id) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar
            
            // 表头 + 歌曲列表（共享宽度）
            GeometryReader { outer in
                let widths = effectiveColumnWidths(totalWidth: outer.size.width)
                
                VStack(spacing: 0) {
                    tableHeader(widths: widths)
                    songList(widths: widths)
                }
            }
            
            // 底部状态栏 / 批量操作
            bottomBar
        }
        .overlay(
            ZStack {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(QingYinColors.cobalt, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(QingYinColors.cobalt.opacity(0.06))
                                .padding(8)
                        )
                    
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(QingYinColors.cobalt)
                        Text("拖放音频文件导入")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(QingYinColors.cobalt)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        )
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: LocalFileService.supportedContentTypes,
            allowsMultipleSelection: true,
            onCompletion: { result in
                switch result {
                case .success(let urls):
                    let newSongs = libraryViewModel.importAudioFiles(from: urls)
                    // 单文件导入时自动播放
                    if newSongs.count == 1, let song = newSongs.first {
                        playerViewModel.play(song: song, queue: libraryViewModel.filteredSongs)
                    }
                case .failure(let error):
                    print("导入失败: \(error.localizedDescription)")
                }
            }
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            let supportedExts: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg"]
            let group = DispatchGroup()
            let lock = NSLock()
            var urls: [URL] = []
            
            for provider in providers {
                print("🔍 provider registered types: \(provider.registeredTypeIdentifiers)")
                
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    defer { group.leave() }
                    guard let item = item else {
                        print("⚠️ loadItem nil, error: \(String(describing: error))")
                        return
                    }
                    print("🎵 item type: \(type(of: item))")
                    
                    var resolvedURL: URL?
                    
                    if let url = item as? URL {
                        resolvedURL = url
                    } else if let nsURL = item as? NSURL {
                        resolvedURL = nsURL as URL
                    } else if let data = item as? Data {
                        if let str = String(data: data, encoding: .utf8) {
                            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("  → Data decoded: '\(trimmed)'")
                            if trimmed.hasPrefix("file://") {
                                resolvedURL = URL(string: trimmed)
                            } else if trimmed.hasPrefix("/") {
                                resolvedURL = URL(fileURLWithPath: trimmed)
                            }
                        }
                    }
                    
                    guard let url = resolvedURL else {
                        print("  → 无法解析 URL")
                        return
                    }
                    print("  → raw URL: \(url)")
                    
                    // 解析 file reference URL（.file/id=xxx）到真实文件路径
                    var finalURL = url
                    if url.isFileURL {
                        if let resolved = try? url.resolvingSymlinksInPath() {
                            finalURL = resolved
                            print("  → resolved: \(finalURL)")
                        }
                    }
                    
                    // 提取扩展名
                    var ext = finalURL.pathExtension.lowercased()
                    print("  → ext from path: '\(ext)'")
                    
                    // 如果扩展名仍为空，从文件内容推断
                    if ext.isEmpty, let resourceValues = try? finalURL.resourceValues(forKeys: [.contentTypeKey]),
                       let contentType = resourceValues.contentType {
                        ext = contentType.preferredFilenameExtension ?? ""
                        print("  → ext from UTType: '\(ext)'")
                    }
                    
                    print("  → final ext: '\(ext)', supported: \(supportedExts.contains(ext))")
                    if supportedExts.contains(ext) {
                        lock.lock()
                        urls.append(finalURL)
                        lock.unlock()
                    }
                }
            }
            
            group.notify(queue: .main) {
                guard !urls.isEmpty else {
                    print("⚠️ onDrop: 没有可导入的音频文件")
                    return
                }
                let newSongs = libraryViewModel.importAudioFiles(from: urls)
                print("✅ 导入了 \(newSongs.count) 首新歌曲")
                if newSongs.count == 1, let song = newSongs.first {
                    playerViewModel.play(song: song, queue: libraryViewModel.filteredSongs)
                }
            }
            return true
        }
        .sheet(isPresented: $showingAddToPlaylist) {
            AddToPlaylistSheet(songs: selectedSongs) { playlist in
                for song in selectedSongs {
                    libraryViewModel.addSongsToPlaylist([song], playlist: playlist)
                }
                selectedSongIDs.removeAll()
            }
        }
    }
    
    // MARK: - Toolbar
    private var toolbar: some View {
        HStack {
            Text(libraryViewModel.activeFilter.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(QingYinColors.ink)
            
            if case .all = libraryViewModel.activeFilter {
                EmptyView()
            } else {
                Button(action: { libraryViewModel.clearFilter() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(QingYinColors.inkMist)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(QingYinColors.inkMist)
                    .font(.system(size: 12))
                TextField("搜索歌曲、艺术家、专辑...", text: $libraryViewModel.searchText)
                    .font(.system(size: 13))
                    .frame(width: 200)
            }
            .padding(6)
            .background(QingYinColors.porcelain)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
            )
            
            Button(action: { showingFileImporter = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                    Text("导入")
                        .font(.system(size: 12))
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
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Table Header
    private func tableHeader(widths: [Column: CGFloat]) -> some View {
        HStack(spacing: 0) {
            ForEach(columnOrder) { column in
                headerCell(for: column, widths: widths)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 24)
        .background(QingYinColors.porcelainWarm)
        .overlay(
            Rectangle()
                .fill(QingYinColors.cobalt.opacity(0.06))
                .frame(height: 1)
            , alignment: .bottom
        )
    }
    
    private func headerCell(for column: Column, widths: [Column: CGFloat]) -> some View {
        HStack(spacing: 0) {
            Text(column.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(QingYinColors.inkMist)
                .lineLimit(1)
            
            if libraryViewModel.sortKey == sortKey(for: column) {
                Image(systemName: libraryViewModel.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(QingYinColors.cobalt)
                    .padding(.leading, 2)
            }
            
            Spacer()
            
            if column.isResizable && !column.isFlexible {
                Rectangle()
                    .fill(QingYinColors.cobalt.opacity(0.2))
                    .frame(width: 1)
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if resizingColumn == nil {
                                    resizingColumn = column
                                    resizeStartX = value.location.x
                                    resizeStartWidth = columnWidths[column] ?? 80
                                }
                                let delta = value.location.x - resizeStartX
                                columnWidths[column] = max(40, resizeStartWidth + delta)
                            }
                            .onEnded { _ in
                                resizingColumn = nil
                                saveColumnSettings()
                            }
                    )
            }
        }
        .frame(width: widths[column] ?? 80, alignment: .leading)
        .contentShape(Rectangle())
        .background(draggingColumn == column ? QingYinColors.cobaltGhost : Color.clear)
        .onTapGesture {
            if let key = sortKey(for: column) {
                libraryViewModel.toggleSort(key)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { _ in }
                .onEnded { value in
                    handleColumnReorder(column: column, translation: value.translation.width)
                }
        )
    }
    
    private func handleColumnReorder(column: Column, translation: CGFloat) {
        guard let currentIndex = columnOrder.firstIndex(of: column) else { return }
        let threshold: CGFloat = 60
        let direction = translation > 0 ? 1 : -1
        let steps = Int(abs(translation) / threshold)
        
        if steps > 0 {
            let newIndex = max(0, min(columnOrder.count - 1, currentIndex + direction * steps))
            if newIndex != currentIndex {
                var newOrder = columnOrder
                newOrder.remove(at: currentIndex)
                newOrder.insert(column, at: newIndex)
                columnOrder = newOrder
                saveColumnSettings()
            }
        }
    }
    
    private func sortKey(for column: Column) -> LibraryViewModel.SortKey? {
        switch column {
        case .title: return .title
        case .artist: return .artist
        case .album: return .album
        case .duration: return .duration
        default: return nil
        }
    }
    
    // MARK: - Song List
    private func songList(widths: [Column: CGFloat]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(libraryViewModel.filteredSongs.enumerated()), id: \.element.id) { index, song in
                    MacSongRow(
                        index: index + 1,
                        song: song,
                        isSelected: selectedSongIDs.contains(song.id),
                        columnWidths: widths,
                        columnOrder: columnOrder,
                        onSelect: { modifierFlags in
                            handleSelection(song: song, modifierFlags: modifierFlags)
                        },
                        onPlay: {
                            playerViewModel.play(song: song, queue: libraryViewModel.filteredSongs)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .background(QingYinColors.porcelain)
    }
    
    // MARK: - Selection
    private func handleSelection(song: Song, modifierFlags: NSEvent.ModifierFlags) {
        let isCommand = modifierFlags.contains(.command)
        let isShift = modifierFlags.contains(.shift)
        
        if isCommand {
            if selectedSongIDs.contains(song.id) {
                selectedSongIDs.remove(song.id)
            } else {
                selectedSongIDs.insert(song.id)
            }
        } else if isShift {
            selectedSongIDs.insert(song.id)
        } else {
            selectedSongIDs = [song.id]
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            if selectedSongIDs.isEmpty {
                Text("\(libraryViewModel.filteredSongs.count) 首歌曲")
                    .font(.system(size: 12))
                    .foregroundColor(QingYinColors.inkMist)
            } else {
                HStack(spacing: 12) {
                    Text("已选择 \(selectedSongIDs.count) 首")
                        .font(.system(size: 12))
                        .foregroundColor(QingYinColors.cobalt)
                    
                    Button(action: { playerViewModel.play(song: selectedSongs.first!, queue: selectedSongs) }) {
                        Label("播放", systemImage: "play.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedSongs.isEmpty)
                    
                    Button(action: { showingAddToPlaylist = true }) {
                        Label("添加到列表", systemImage: "list.bullet")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        for song in selectedSongs {
                            libraryViewModel.playNext(song)
                        }
                        selectedSongIDs.removeAll()
                    }) {
                        Label("下一首播放", systemImage: "text.insert")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { selectedSongIDs.removeAll() }) {
                        Label("取消选择", systemImage: "xmark")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    
                    if selectedSongs.allSatisfy({ libraryViewModel.canDelete($0) }) {
                        Button(role: .destructive, action: {
                            for song in selectedSongs {
                                libraryViewModel.deleteSong(song)
                            }
                            selectedSongIDs.removeAll()
                        }) {
                            Label("删除", systemImage: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(QingYinColors.porcelainWarm)
        .overlay(
            Rectangle()
                .fill(QingYinColors.cobalt.opacity(0.06))
                .frame(height: 1)
            , alignment: .top
        )
    }
}

// MARK: - Add to Playlist Sheet
struct AddToPlaylistSheet: View {
    let songs: [Song]
    let onSelect: (Playlist) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("添加到播放列表")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            
            List {
                ForEach(libraryViewModel.playlists) { playlist in
                    Button(action: {
                        onSelect(playlist)
                        dismiss()
                    }) {
                        HStack {
                            Text(playlist.name)
                                .font(.system(size: 14))
                            Spacer()
                            Text("\(playlist.songIDs.count) 首")
                                .font(.system(size: 12))
                                .foregroundColor(QingYinColors.inkMist)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(QingYinColors.porcelain)
                }
            }
            .listStyle(.plain)
        }
        .frame(width: 300, height: 300)
    }
}

// MARK: - Song Row
struct MacSongRow: View {
    let index: Int
    let song: Song
    let isSelected: Bool
    let columnWidths: [MacLibraryView.Column: CGFloat]
    let columnOrder: [MacLibraryView.Column]
    let onSelect: (NSEvent.ModifierFlags) -> Void
    let onPlay: () -> Void
    
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var isHovered = false
    
    var isCurrentSong: Bool {
        playerViewModel.currentSong?.id == song.id
    }
    
    var isPlaying: Bool {
        isCurrentSong && playerViewModel.isPlaying
    }
    
    var isFavorite: Bool {
        libraryViewModel.isFavorite(song)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(columnOrder, id: \.self) { column in
                cell(for: column)
                    .frame(width: columnWidths[column] ?? 80, alignment: alignment(for: column))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPlay()
        }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            onSelect(flags)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            contextMenu
        }
    }
    
    private func alignment(for column: MacLibraryView.Column) -> Alignment {
        switch column {
        case .index: return .center
        case .duration: return .trailing
        case .favorite: return .center
        default: return .leading
        }
    }
    
    @ViewBuilder
    private func cell(for column: MacLibraryView.Column) -> some View {
        switch column {
        case .index:
            indexCell
        case .title:
            titleCell
        case .artist:
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundColor(QingYinColors.inkMist)
                .lineLimit(1)
        case .album:
            Text(song.album)
                .font(.system(size: 12))
                .foregroundColor(QingYinColors.inkMist)
                .lineLimit(1)
        case .duration:
            durationCell
        case .favorite:
            favoriteCell
        }
    }
    
    private var indexCell: some View {
        ZStack {
            if isPlaying {
                HStack(spacing: 2) {
                    ForEach(0..<4) { i in
                        EQBar(index: i)
                            .frame(width: 2)
                    }
                }
                .frame(height: 20)
            } else {
                Text("\(index)")
                    .font(.system(size: 12, weight: isCurrentSong ? .medium : .regular))
                    .foregroundColor(isCurrentSong ? QingYinColors.cobalt : QingYinColors.inkMist)
            }
        }
    }
    
    private var titleCell: some View {
        HStack(spacing: 10) {
            ZStack {
                if let artwork = song.artwork {
                    artwork
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(songArtColor)
                        .frame(width: 34, height: 34)
                }
                
                RoundedRectangle(cornerRadius: 4)
                    .stroke(QingYinColors.cobalt.opacity(0.1), lineWidth: 1)
                    .frame(width: 34, height: 34)
            }
            
            Text(song.title)
                .font(.system(size: 13, weight: isCurrentSong ? .medium : .regular))
                .foregroundColor(isCurrentSong ? QingYinColors.cobalt : QingYinColors.ink)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var durationCell: some View {
        if isHovered && !isCurrentSong {
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundColor(QingYinColors.cobalt)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        } else {
            Text(song.formattedDuration)
                .font(.system(size: 12))
                .foregroundColor(QingYinColors.inkMist)
        }
    }
    
    private var favoriteCell: some View {
        Button(action: { libraryViewModel.toggleFavorite(song) }) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 12))
                .foregroundColor(isFavorite ? QingYinColors.cobalt : QingYinColors.inkMist)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var contextMenu: some View {
        Button(action: onPlay) {
            Label("播放", systemImage: "play.fill")
        }
        
        Button(action: { libraryViewModel.playNext(song) }) {
            Label("下一首播放", systemImage: "text.insert")
        }
        
        Divider()
        
        Button(action: { libraryViewModel.toggleFavorite(song) }) {
            Label(isFavorite ? "取消喜欢" : "喜欢", systemImage: isFavorite ? "heart.fill" : "heart")
        }
        
        Button(action: { libraryViewModel.filterByAlbum(song.album) }) {
            Label("查看专辑", systemImage: "square.stack")
        }
        .disabled(song.album.isEmpty)
        
        Button(action: { libraryViewModel.filterByArtist(song.artist) }) {
            Label("查看艺术家", systemImage: "person")
        }
        .disabled(song.artist.isEmpty)
        
        Divider()
        
        if libraryViewModel.canDelete(song) {
            Button(role: .destructive, action: { libraryViewModel.deleteSong(song) }) {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected || isCurrentSong {
            return QingYinColors.cobaltGhost
        }
        if isHovered {
            return QingYinColors.porcelainWarm.opacity(0.8)
        }
        return QingYinColors.porcelain
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

// MARK: - Dictionary Helper
extension Dictionary where Key == MacLibraryView.Column, Value == CGFloat {
    func mapKeys(_ transform: (Key) -> String) -> [String: CGFloat] {
        var result: [String: CGFloat] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}

#else

import SwiftUI

struct MacLibraryView: View {
    var body: some View {
        Text("Mac 音乐库")
    }
}

#endif
