//
//  NowPlayingView.swift
//  正在播放全屏页面
//

import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showEqualizer = false
    @State private var showErrorAlert = false
    
    var body: some View {
        ZStack {
            QingYinColors.porcelain.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(QingYinColors.inkMist)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("正在播放")
                        .font(.system(size: 12))
                        .foregroundColor(QingYinColors.inkMist)
                        .tracking(1)
                    
                    Spacer()
                    
                    Button(action: { showEqualizer = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundColor(QingYinColors.inkMist)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer().frame(height: 30)
                
                // 青花瓷圆盘封面
                ZStack {
                    if let artwork = playerViewModel.currentSong?.artwork {
                        artwork
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(QingYinColors.cobaltPale)
                            .frame(width: 220, height: 220)
                        
                        Circle()
                            .stroke(QingYinColors.cobalt.opacity(0.1), lineWidth: 1)
                            .frame(width: 196, height: 196)
                        
                        Circle()
                            .fill(QingYinColors.porcelain)
                            .frame(width: 160, height: 160)
                        
                        Circle()
                            .stroke(QingYinColors.cobalt.opacity(0.08), lineWidth: 1)
                            .frame(width: 130, height: 130)
                        
                        // 中心花纹
                        Image(systemName: "music.note")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(QingYinColors.cobalt.opacity(0.2))
                    }
                }
                .shadow(color: QingYinColors.cobalt.opacity(0.08), radius: 20, x: 0, y: 10)
                
                Spacer().frame(height: 40)
                
                // 歌曲信息
                VStack(spacing: 6) {
                    Text(playerViewModel.currentSong?.title ?? "未知歌曲")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(QingYinColors.ink)
                    
                    Text(playerViewModel.currentSong?.artist ?? "未知艺术家")
                        .font(.system(size: 14))
                        .foregroundColor(QingYinColors.celadon)
                }
                
                Spacer().frame(height: 28)
                
                // 进度条
                VStack(spacing: 6) {
                    ProgressSlider(
                        progress: playerViewModel.progress,
                        onSeek: { playerViewModel.seek(to: $0) }
                    )
                    
                    HStack {
                        Text(formatTime(playerViewModel.currentTime))
                        Spacer()
                        Text(formatTime(playerViewModel.duration))
                    }
                    .font(.system(size: 10))
                    .foregroundColor(QingYinColors.inkMist)
                }
                .padding(.horizontal, 32)
                
                Spacer().frame(height: 28)
                
                // 播放控制
                HStack(spacing: 32) {
                    Button(action: { playerViewModel.player.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 16))
                            .foregroundColor(playerViewModel.isShuffleOn ? QingYinColors.cobalt : QingYinColors.inkMist)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: playerViewModel.previous) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18))
                            .foregroundColor(QingYinColors.ink)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: playerViewModel.togglePlayPause) {
                        ZStack {
                            Circle()
                                .stroke(QingYinColors.cobalt, lineWidth: 1.5)
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .foregroundColor(QingYinColors.cobalt)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: playerViewModel.next) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                            .foregroundColor(QingYinColors.ink)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { playerViewModel.player.cycleRepeatMode() }) {
                        Image(systemName: repeatImageName)
                            .font(.system(size: 16))
                            .foregroundColor(repeatColor)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer().frame(height: 40)
                
                // 音量控制
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 11))
                            .foregroundColor(QingYinColors.inkMist)
                        
                        ProgressSlider(
                            progress: Double(playerViewModel.volume),
                            onSeek: {
                                let v = Float($0)
                                playerViewModel.volume = v
                                playerViewModel.player.volume = v
                            }
                        )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 12)
                
                // 底部功能
                HStack(spacing: 40) {
                    Button(action: { showLyrics = true }) {
                        BottomActionButton(icon: "quote.bubble", title: "歌词")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showQueue = true }) {
                        BottomActionButton(icon: "list.bullet", title: "队列")
                    }
                    .buttonStyle(.plain)
                    
                    ShareLink(item: shareURL, preview: SharePreview(shareTitle, image: Image(systemName: "music.note"))) {
                        BottomActionButton(icon: "square.and.arrow.up", title: "分享")
                    }
                    
                    Button(action: { toggleFavorite() }) {
                        BottomActionButton(
                            icon: isFavorite ? "heart.fill" : "heart",
                            title: "收藏"
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showLyrics) {
            LyricsView()
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerView()
        }
        .onChange(of: playerViewModel.player.errorMessage) { newValue in
            if newValue != nil {
                showErrorAlert = true
            }
        }
        .alert("播放错误", isPresented: $showErrorAlert) {
            Button("确定") {
                showErrorAlert = false
                playerViewModel.player.errorMessage = nil
            }
        } message: {
            Text(playerViewModel.player.errorMessage ?? "")
        }
    }
    
    private var shareURL: URL {
        // 优先分享音频文件 URL，否则分享文本
        if let assetURL = playerViewModel.currentSong?.assetURL {
            return assetURL
        }
        return URL(string: "https://qingyin.app") ?? URL(fileURLWithPath: "")
    }
    
    private var shareTitle: String {
        guard let song = playerViewModel.currentSong else { return "清音" }
        return "\(song.title) - \(song.artist)"
    }
    
    private var repeatImageName: String {
        switch playerViewModel.repeatMode {
        case .off: return "arrow.triangle.2.circlepath"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private var repeatColor: Color {
        playerViewModel.repeatMode == .off ? QingYinColors.inkMist : QingYinColors.cobalt
    }
    
    private func toggleFavorite() {
        guard let song = playerViewModel.currentSong else { return }
        libraryViewModel.toggleFavorite(song)
    }
    
    private var isFavorite: Bool {
        guard let song = playerViewModel.currentSong else { return false }
        return libraryViewModel.isFavorite(song)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Bottom Action Button
struct BottomActionButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(QingYinColors.inkMist)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(QingYinColors.inkMist)
        }
    }
}
