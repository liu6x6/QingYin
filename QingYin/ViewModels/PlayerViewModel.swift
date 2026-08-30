//
//  PlayerViewModel.swift
//  播放器视图模型
//

import Foundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var isNowPlayingPresented: Bool = false
    
    // 从 AudioPlayerManager 转发的播放进度属性
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var volume: Float = 1.0
    @Published var isShuffleOn: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var equalizerSettings: EqualizerSettings = .default
    
    // 歌词：优先从歌曲自带，否则自动在线搜索
    @Published var currentLyrics: String? = nil
    @Published var isLyricsLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    let player = AudioPlayerManager.shared
    
    init() {
        // 监听播放状态变化
        player.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] song in
                // 恢复播放时不弹出 NowPlaying
                guard song != nil, !(self?.player.isRestoring ?? false) else { return }
                self?.isNowPlayingPresented = true
            }
            .store(in: &cancellables)
        
        // iOS 播放界面使用视图模型转发的进度。macOS 由底部播放条直接观察音频引擎，
        // 避免高频进度更新重建资料库中的 AppKit 上下文菜单。
        #if !os(macOS)
        player.$currentTime
            .assign(to: &$currentTime)
        player.$duration
            .assign(to: &$duration)
        player.$progress
            .assign(to: &$progress)
        #endif
        player.$volume
            .assign(to: &$volume)
        player.$isShuffleOn
            .assign(to: &$isShuffleOn)
        player.$repeatMode
            .assign(to: &$repeatMode)
        player.$equalizerSettings
            .assign(to: &$equalizerSettings)
        
        // 歌曲切换时自动获取歌词
        player.$currentSong
            .compactMap { $0 }
            .removeDuplicates(by: { $0.id == $1.id })
            .sink { [weak self] song in
                self?.fetchLyrics(for: song)
            }
            .store(in: &cancellables)
    }
    
    private func fetchLyrics(for song: Song) {
        // 歌曲自带歌词，直接使用
        if let embedded = song.lyrics, !embedded.isEmpty {
            currentLyrics = embedded
            isLyricsLoading = false
            return
        }
        
        // 自动在线搜索
        isLyricsLoading = true
        currentLyrics = nil
        
        Task {
            let lyrics = await LyricsService.shared.getLyrics(for: song)
            // 确保仍然是同一首歌（防止切歌后覆盖）
            if player.currentSong?.id == song.id {
                currentLyrics = lyrics
                isLyricsLoading = false
            }
        }
    }
    
    var currentSong: Song? {
        player.currentSong
    }
    
    var isPlaying: Bool {
        player.playbackState == .playing
    }
    
    func play(song: Song, queue: [Song] = []) {
        player.play(song: song, queue: queue)
    }
    
    func togglePlayPause() {
        player.togglePlayPause()
    }
    
    func next() {
        player.nextTrack()
    }
    
    func previous() {
        player.previousTrack()
    }
    
    func seek(to progress: Double) {
        player.seek(to: progress)
    }

    func setEqualizerEnabled(_ isEnabled: Bool) {
        player.setEqualizerEnabled(isEnabled)
    }

    func selectEqualizerPreset(_ preset: EqualizerPreset) {
        player.selectEqualizerPreset(preset)
    }

    func setEqualizerGain(_ gain: Float, at index: Int) {
        player.setEqualizerGain(gain, at: index)
    }

    func setPreampGain(_ gain: Float) {
        player.setPreampGain(gain)
    }

    func resetEqualizer() {
        player.resetEqualizer()
    }
}

/// 为列表行提供播放状态，避免播放进度刷新重建整行。
@MainActor
final class PlaybackIndicatorState: ObservableObject {
    static let shared = PlaybackIndicatorState()

    @Published private(set) var currentSongID: UUID?
    @Published private(set) var isPlaying = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let player = AudioPlayerManager.shared
        player.$currentSong
            .map { $0?.id }
            .sink { [weak self] in self?.currentSongID = $0 }
            .store(in: &cancellables)
        player.$playbackState
            .map { $0 == .playing }
            .sink { [weak self] in self?.isPlaying = $0 }
            .store(in: &cancellables)
    }
}
