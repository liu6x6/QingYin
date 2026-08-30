//
//  LyricsPanelView.swift
//  Apple Music 风格全屏歌词面板
//

import SwiftUI

struct LyricsPanelView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    let onClose: () -> Void

    @State private var parsedLyrics: [LyricsLine] = []
    @State private var currentLineIndex: Int? = nil
    @State private var appearAnimation = false
    @State private var currentTime: TimeInterval = 0

    private let audioPlayer = AudioPlayerManager.shared

    /// 歌词来源：优先 PlayerViewModel 自动获取的，其次歌曲自带的
    private var lyricsText: String? {
        playerViewModel.currentLyrics ?? playerViewModel.currentSong?.lyrics
    }

    var body: some View {
        ZStack {
            // 全屏背景
            backgroundLayer

            // 主内容
            HStack(spacing: 0) {
                // 左侧：播放器
                playerSide
                    .frame(width: 320)
                    .padding(.leading, 40)

                // 右侧：歌词
                lyricsSide
                    .padding(.horizontal, 40)
            }
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 20)

            // 右上角关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(QingYinColors.inkMist)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle().fill(QingYinColors.porcelainDeep.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            loadLyrics()
            syncTime()
            withAnimation(.easeOut(duration: 0.4)) {
                appearAnimation = true
            }
        }
        .onChange(of: playerViewModel.currentSong) { _ in
            loadLyrics()
        }
        .onChange(of: playerViewModel.currentLyrics) { _ in
            loadLyrics()
        }
        // 直接监听 AudioPlayerManager 的时间（macOS/iOS 通用）
        .onReceive(audioPlayer.$currentTime) { time in
            currentTime = time
            updateCurrentLine(time: time)
        }
    }

    // MARK: - Background
    private var backgroundLayer: some View {
        ZStack {
            // 基础底色
            QingYinColors.porcelain.ignoresSafeArea()

            // 根据封面生成模糊背景色
            if playerViewModel.currentSong?.artwork != nil {
                // 有封面时添加模糊效果
                QingYinColors.cobaltGhost.opacity(0.3).ignoresSafeArea()
            }
        }
    }

    // MARK: - Left: Player
    private var playerSide: some View {
        VStack(spacing: 0) {
            Spacer()

            // 大封面
            ZStack {
                if let artwork = playerViewModel.currentSong?.artwork {
                    artwork
                        .resizable()
                        .scaledToFill()
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(QingYinColors.cobaltPale)
                        .frame(width: 240, height: 240)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(QingYinColors.cobalt.opacity(0.2))
                        )
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)

            Spacer().frame(height: 28)

            // 歌曲信息
            VStack(spacing: 6) {
                Text(playerViewModel.currentSong?.title ?? "未在播放")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(QingYinColors.ink)
                    .lineLimit(1)

                Text(playerViewModel.currentSong?.artist ?? "")
                    .font(.system(size: 14))
                    .foregroundColor(QingYinColors.celadon)
                    .lineLimit(1)
            }

            Spacer().frame(height: 24)

            // 进度条
            VStack(spacing: 6) {
                ProgressSlider(
                    progress: audioPlayer.progress,
                    onSeek: { audioPlayer.seek(to: $0) }
                )

                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(audioPlayer.duration))
                }
                .font(.system(size: 10))
                .foregroundColor(QingYinColors.inkMist)
                .monospacedDigit()
            }

            Spacer().frame(height: 20)

            // 播放控制
            HStack(spacing: 28) {
                Button(action: { audioPlayer.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 14))
                        .foregroundColor(audioPlayer.isShuffleOn ? QingYinColors.cobalt : QingYinColors.inkMist)
                }
                .buttonStyle(.plain)

                Button(action: audioPlayer.previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(QingYinColors.ink)
                }
                .buttonStyle(.plain)

                Button(action: audioPlayer.togglePlayPause) {
                    ZStack {
                        Circle()
                            .stroke(QingYinColors.cobalt, lineWidth: 1.5)
                            .frame(width: 48, height: 48)
                        Image(systemName: audioPlayer.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(QingYinColors.cobalt)
                    }
                }
                .buttonStyle(.plain)

                Button(action: audioPlayer.nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(QingYinColors.ink)
                }
                .buttonStyle(.plain)

                Button(action: { audioPlayer.cycleRepeatMode() }) {
                    Image(systemName: repeatIcon)
                        .font(.system(size: 14))
                        .foregroundColor(repeatColor)
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: 16)

            // 底部操作
            HStack(spacing: 20) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(isFavorite ? QingYinColors.cobalt : QingYinColors.inkMist)
                }
                .buttonStyle(.plain)

                Spacer()

                // 音量
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.1.fill")
                        .font(.system(size: 10))
                        .foregroundColor(QingYinColors.inkMist)

                    ProgressSlider(
                        progress: Double(audioPlayer.volume),
                        onSeek: { audioPlayer.volume = Float($0) }
                    )
                    .frame(width: 80)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 10))
                        .foregroundColor(QingYinColors.inkMist)
                }
            }

            Spacer()
        }
    }

    // MARK: - Right: Lyrics
    private var lyricsSide: some View {
        VStack(alignment: .leading, spacing: 0) {
            if parsedLyrics.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    if playerViewModel.isLyricsLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        Text("搜索歌词中...")
                            .font(.system(size: 14))
                            .foregroundColor(QingYinColors.inkMist)
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(QingYinColors.cobalt.opacity(0.2))
                        Text("暂无歌词")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(QingYinColors.inkMist.opacity(0.5))
                        if lyricsText == nil {
                            Text("未找到匹配的歌词")
                                .font(.system(size: 12))
                                .foregroundColor(QingYinColors.inkMist.opacity(0.35))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                lyricsScrollView
            }
        }
    }

    private var lyricsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // 顶部留白，让第一行歌词可滚到视觉中心
                Color.clear.frame(height: 200)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(parsedLyrics.enumerated()), id: \.element.id) { index, line in
                        lyricsLineView(line: line, index: index)
                            .id(index)
                    }
                }

                // 底部留白
                Color.clear.frame(height: 280)
            }
            .onChange(of: currentLineIndex) { newIndex in
                guard let newIndex = newIndex else { return }
                withAnimation(.easeInOut(duration: 0.6)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Lyrics Line
    private func lyricsLineView(line: LyricsLine, index: Int) -> some View {
        let isCurrent = index == currentLineIndex
        let isPast = (currentLineIndex ?? -1) > index
        let distance = abs(index - (currentLineIndex ?? -1))

        return Text(line.text)
            .font(.system(
                size: isCurrent ? 22 : 17,
                weight: isCurrent ? .bold : .medium
            ))
            .foregroundColor(
                isCurrent ? QingYinColors.cobalt :
                isPast ? QingYinColors.ink.opacity(0.35) :
                opacityForDistance(distance)
            )
            .lineSpacing(6)
            .padding(.vertical, isCurrent ? 10 : 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(isCurrent ? 1.03 : 1.0, anchor: .leading)
            .animation(.easeInOut(duration: 0.35), value: isCurrent)
            .contentShape(Rectangle())
            .onTapGesture {
                // 点击歌词行 → 跳转到对应时间
                guard audioPlayer.duration > 0 else { return }
                let progress = line.time / audioPlayer.duration
                audioPlayer.seek(to: progress)
                // 如果是暂停状态，点击后自动播放
                if audioPlayer.playbackState != .playing {
                    audioPlayer.resume()
                }
            }
            .onHover { hovering in
                // hover 时显示时间标签（可选）
            }
    }

    private func opacityForDistance(_ distance: Int) -> Color {
        switch distance {
        case 0: return QingYinColors.cobalt
        case 1: return QingYinColors.ink.opacity(0.5)
        case 2: return QingYinColors.ink.opacity(0.35)
        case 3: return QingYinColors.inkMist.opacity(0.3)
        default: return QingYinColors.inkMist.opacity(0.2)
        }
    }

    // MARK: - Helpers
    private func syncTime() {
        currentTime = audioPlayer.currentTime
        currentLineIndex = parsedLyrics.currentIndex(at: currentTime)
    }

    private func loadLyrics() {
        if let lyrics = lyricsText, !lyrics.isEmpty {
            parsedLyrics = LyricsParser.parse(lyrics)
        } else {
            parsedLyrics = []
        }
        currentLineIndex = parsedLyrics.currentIndex(at: currentTime)
    }

    private func updateCurrentLine(time: TimeInterval) {
        let newIndex = parsedLyrics.currentIndex(at: time)
        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
        }
    }

    private var repeatIcon: String {
        switch audioPlayer.repeatMode {
        case .off: return "arrow.triangle.2.circlepath"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private var repeatColor: Color {
        audioPlayer.repeatMode == .off ? QingYinColors.inkMist : QingYinColors.cobalt
    }

    private var isFavorite: Bool {
        guard let song = playerViewModel.currentSong else { return false }
        return libraryViewModel.isFavorite(song)
    }

    private func toggleFavorite() {
        guard let song = playerViewModel.currentSong else { return }
        libraryViewModel.toggleFavorite(song)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
