//
//  MacPlayerBar.swift
//  macOS 底部播放控制条
//

import SwiftUI

struct MacPlayerBar: View {
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：当前歌曲信息
            HStack(spacing: 10) {
                ZStack {
                    if let artwork = audioPlayer.currentSong?.artwork {
                        artwork
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(QingYinColors.cobaltPale)
                            .frame(width: 40, height: 40)
                    }
                    
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(QingYinColors.cobalt.opacity(0.1), lineWidth: 1)
                        .frame(width: 40, height: 40)
                    
                    if audioPlayer.currentSong?.artwork == nil {
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundColor(QingYinColors.cobalt.opacity(0.4))
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioPlayer.currentSong?.title ?? "未在播放")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(QingYinColors.ink)
                        .lineLimit(1)
                    
                    Text(audioPlayer.currentSong?.artist ?? "选择一首歌开始播放")
                        .font(.system(size: 11))
                        .foregroundColor(QingYinColors.inkMist)
                        .lineLimit(1)
                }
                .frame(width: 120, alignment: .leading)
            }
            
            // 中间：控制 + 进度
            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    Button(action: { audioPlayer.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 11))
                            .foregroundColor(audioPlayer.isShuffleOn ? QingYinColors.cobalt : QingYinColors.inkMist)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: audioPlayer.previousTrack) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(QingYinColors.ink)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: audioPlayer.togglePlayPause) {
                        Image(systemName: audioPlayer.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(QingYinColors.cobalt)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: audioPlayer.nextTrack) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(QingYinColors.ink)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { audioPlayer.cycleRepeatMode() }) {
                        Image(systemName: repeatImageName)
                            .font(.system(size: 11))
                            .foregroundColor(repeatColor)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 8) {
                    Text(formatTime(audioPlayer.currentTime))
                        .font(.system(size: 9))
                        .foregroundColor(QingYinColors.inkMist)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .leading)
                    
                    ProgressSlider(
                        progress: audioPlayer.progress,
                        onSeek: { audioPlayer.seek(to: $0) }
                    )
                    
                    Text(formatTime(audioPlayer.duration))
                        .font(.system(size: 9))
                        .foregroundColor(QingYinColors.inkMist)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)
            
            // 右侧：音量
            HStack(spacing: 8) {
                Button(action: { showEqualizer = true }) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 12))
                        .foregroundColor(audioPlayer.equalizerSettings.isEnabled ? QingYinColors.cobalt : QingYinColors.inkMist)
                }
                .buttonStyle(.plain)
                .help("均衡器")

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(QingYinColors.inkMist)
                
                ProgressSlider(
                    progress: Double(audioPlayer.volume),
                    onSeek: {
                        let v = Float($0)
                        audioPlayer.volume = v
                    }
                )
            }
            .frame(width: 100)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(QingYinColors.porcelainWarm)
        .overlay(
            Rectangle()
                .fill(QingYinColors.cobalt.opacity(0.06))
                .frame(height: 1)
            , alignment: .top
        )
        .sheet(isPresented: $showEqualizer) {
            EqualizerView()
        }
    }

    @State private var showEqualizer = false
    
    private var repeatImageName: String {
        switch audioPlayer.repeatMode {
        case .off: return "arrow.triangle.2.circlepath"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private var repeatColor: Color {
        audioPlayer.repeatMode == .off ? QingYinColors.inkMist : QingYinColors.cobalt
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Progress Slider
struct ProgressSlider: View {
    let progress: Double
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var isHovering = false
    @State private var lastSeekValue: Double = -1
    @State private var lastSeekTime: Date = .distantPast
    
    private var displayProgress: Double {
        if isDragging {
            return dragProgress
        }
        // seek 后锁定在拖拽位置，直到 progress 追上来
        if lastSeekValue >= 0 {
            return lastSeekValue
        }
        return max(0, min(1, progress))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let thumbX = CGFloat(displayProgress) * trackWidth
            
            ZStack(alignment: .leading) {
                // 轨道背景
                Capsule()
                    .fill(QingYinColors.porcelainDeep)
                    .frame(height: 3)
                
                // 已播放进度
                Capsule()
                    .fill(QingYinColors.cobalt)
                    .frame(width: max(0, thumbX), height: 3)
                
                // 拖拽把手
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(QingYinColors.cobalt, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .opacity(isDragging || isHovering ? 1 : 0)
                    .offset(x: thumbX - 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onChange(of: progress) { newValue in
                // 外部 progress 追上拖拽值后解锁，或 progress 归零（切歌）时解锁
                if lastSeekValue >= 0 {
                    if abs(newValue - lastSeekValue) < 0.015 || newValue < 0.001 {
                        lastSeekValue = -1
                    }
                }
            }
            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                // 2 秒安全超时，防止 progress 永不更新导致锁定
                if lastSeekValue >= 0, Date().timeIntervalSince(lastSeekTime) > 2 {
                    lastSeekValue = -1
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging { isDragging = true }
                        dragProgress = Double(max(0, min(1, value.location.x / trackWidth)))
                    }
                    .onEnded { value in
                        let p = Double(max(0, min(1, value.location.x / trackWidth)))
                        lastSeekValue = p  // 锁定到拖拽位置，防止回弹
                        lastSeekTime = Date()
                        isDragging = false
                        onSeek(p)
                    }
            )
        }
        .frame(height: 20)
    }
}
