//
//  AudioPlayerManager.swift
//  音频播放核心（使用 AVPlayer）
//

import AVFoundation
import Combine
import SwiftUI

enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
}

enum RepeatMode: String, Equatable, CaseIterable {
    case off
    case one
    case all
}

@MainActor
final class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var queue: [Song] = []
    @Published var currentIndex: Int = 0
    @Published var isShuffleOn: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var volume: Float = 1.0
    @Published var errorMessage: String?
    /// 是否为恢复播放（不触发 NowPlaying 弹窗）
    var isRestoring: Bool = false
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var finishObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    // seek 保护：用代际计数器 + 时间戳，防止 observer 旧值覆盖
    private var seekGeneration: Int = 0
    private var lastSeekWallTime: Date = .distantPast
    // 随机播放：打乱后的播放顺序 + 历史栈（支持返回上一首）
    private var shuffledOrder: [Int] = []
    private var shuffledPointer: Int = 0
    
    // MARK: - UserDefaults Keys
    private enum PersistenceKey: String {
        case lastPlayedSongID = "qingyin.lastPlayedSongID"
        case lastPlayedTime = "qingyin.lastPlayedTime"
        case lastPlayedQueue = "qingyin.lastPlayedQueue"
        case lastPlayedIndex = "qingyin.lastPlayedIndex"
        case isShuffleOn = "qingyin.isShuffleOn"
        case repeatMode = "qingyin.repeatMode"
    }
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        
        // 监听音量变化
        $volume
            .dropFirst()
            .sink { [weak self] newVolume in
                self?.player?.volume = newVolume
            }
            .store(in: &cancellables)
        
        // 监听当前歌曲变化，保存歌曲 ID
        $currentSong
            .compactMap { $0?.id }
            .sink { songID in
                UserDefaults.standard.set(songID.uuidString, forKey: PersistenceKey.lastPlayedSongID.rawValue)
            }
            .store(in: &cancellables)
        
        // 监听播放状态变化（暂停/恢复），保存当前播放位置
        $playbackState
            .sink { [weak self] state in
                guard let self = self else { return }
                if state == .paused || state == .stopped {
                    self.saveCurrentTime()
                }
            }
            .store(in: &cancellables)
        
        // 定期保存播放位置（每 5 秒），不写入过于频繁
        $currentTime
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.saveCurrentTime()
            }
            .store(in: &cancellables)
        
        // 恢复 shuffle 和 repeat 设置
        isShuffleOn = UserDefaults.standard.bool(forKey: PersistenceKey.isShuffleOn.rawValue)
        if let mode = UserDefaults.standard.string(forKey: PersistenceKey.repeatMode.rawValue),
           let repeatMode = RepeatMode(rawValue: mode) {
            self.repeatMode = repeatMode
        }
        
        // 监听设置变化，自动保存
        $isShuffleOn
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: PersistenceKey.isShuffleOn.rawValue) }
            .store(in: &cancellables)
        $repeatMode
            .dropFirst()
            .map { $0.rawValue }
            .sink { UserDefaults.standard.set($0, forKey: PersistenceKey.repeatMode.rawValue) }
            .store(in: &cancellables)
        
        // APP 关闭时保存播放位置
        #if os(macOS)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.saveCurrentTime() }
            .store(in: &cancellables)
        #else
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.saveCurrentTime() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification)
            .sink { [weak self] _ in self?.saveCurrentTime() }
            .store(in: &cancellables)
        #endif
    }
    
    private func saveCurrentTime() {
        UserDefaults.standard.set(currentTime, forKey: PersistenceKey.lastPlayedTime.rawValue)
    }
    
    // MARK: - Audio Session
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            errorMessage = "音频会话配置失败: \(error.localizedDescription)"
        }
        #endif
    }
    
    // MARK: - Restore Last Played
    /// 从可用歌曲列表中恢复上次播放的歌曲（不自动播放，仅加载）
    /// - Returns: true 如果成功恢复
    @discardableResult
    func restoreLastPlayed(from songs: [Song]) -> Bool {
        guard currentSong == nil,
              let idString = UserDefaults.standard.string(forKey: PersistenceKey.lastPlayedSongID.rawValue),
              let songID = UUID(uuidString: idString),
              let song = songs.first(where: { $0.id == songID }) else {
            return false
        }
        
        isRestoring = true
        defer { isRestoring = false }
        
        let savedTime = UserDefaults.standard.double(forKey: PersistenceKey.lastPlayedTime.rawValue)
        
        // 设置为当前歌曲但不播放
        self.queue = songs
        if let index = songs.firstIndex(where: { $0.id == songID }) {
            self.currentIndex = index
        }
        self.currentSong = song
        self.duration = song.duration
        self.currentTime = savedTime
        if song.duration > 0 {
            self.progress = savedTime / song.duration
        }
        
        // 加载播放器以便用户点播放
        if let assetURL = song.assetURL {
            let item = AVPlayerItem(url: assetURL)
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.volume = volume
            self.player = newPlayer
            self.playerItem = item
            
            // seek 到上次位置
            if savedTime > 0 {
                let targetTime = CMTime(seconds: savedTime, preferredTimescale: 600)
                newPlayer.seek(to: targetTime)
            }
            
            // 设置播放结束监听
            finishObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.handlePlaybackFinished() }
            }
            
            // 设置时间监听
            self.lastSeekWallTime = .distantPast  // 确保 observer 不会被初始 seek 阻塞
            let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                Task { @MainActor in
                    guard let self = self else { return }
                    let elapsed = Date().timeIntervalSince(self.lastSeekWallTime)
                    if elapsed < 1.5 { return }
                    let seconds = CMTimeGetSeconds(time)
                    guard seconds.isFinite, !seconds.isNaN else { return }
                    self.currentTime = seconds
                    if self.duration > 0 {
                        self.progress = self.currentTime / self.duration
                    }
                }
            }
        }
        
        print("\(song.title) \(savedTime)s")
        return true
    }
    
    // MARK: - Playback Control
    func play(song: Song, queue: [Song] = []) {
        self.queue = queue.isEmpty ? [song] : queue
        if let index = self.queue.firstIndex(where: { $0.id == song.id }) {
            self.currentIndex = index
        } else {
            self.currentIndex = 0
        }
        
        // 重新打乱随机顺序
        if isShuffleOn {
            reshuffleQueue()
        }
        
        loadAndPlay(song: song)
    }
    
    func addToQueueNext(_ song: Song) {
        let insertIndex = min(currentIndex + 1, queue.count)
        queue.insert(song, at: insertIndex)
    }
    
    func moveQueueItem(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
    }
    
    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .paused, .stopped:
            if currentSong != nil {
                resume()
            }
        }
    }
    
    func pause() {
        player?.pause()
        playbackState = .paused
    }
    
    func resume() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "恢复播放失败: \(error.localizedDescription)"
            return
        }
        #endif
        player?.play()
        playbackState = .playing
    }
    
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        player = nil
        playerItem = nil
        removeObservers()
        playbackState = .stopped
        currentTime = 0
        progress = 0
    }
    
    /// 用户主动按“下一首”
    func nextTrack() {
        advanceToNext(userInitiated: true)
    }
    
    /// 实际执行下一首逻辑
    /// - Parameter userInitiated: true=用户点击下一首；false=歌曲自然播放结束
    private func advanceToNext(userInitiated: Bool) {
        guard !queue.isEmpty else { return }
        
        // 单曲循环 + 非用户主动 → 从头播放同一首
        if repeatMode == .one && !userInitiated {
            lastSeekWallTime = Date()
            player?.seek(to: .zero)
            player?.play()
            playbackState = .playing
            currentTime = 0
            progress = 0
            return
        }
        
        let nextIndex: Int
        if isShuffleOn {
            // 使用打乱顺序，避免连续重复
            ensureShuffledOrder()
            if shuffledPointer < shuffledOrder.count - 1 {
                shuffledPointer += 1
            } else {
                // 已播放完所有歌曲，重新打乱
                reshuffleQueue()
                shuffledPointer = 0
            }
            nextIndex = shuffledOrder[shuffledPointer]
        } else {
            let raw = currentIndex + 1
            // 队列播放完毕
            if raw >= queue.count {
                if repeatMode == .all {
                    nextIndex = 0  // 循环回第一首
                } else {
                    pause()  // 顺序播放结束，暂停
                    return
                }
            } else {
                nextIndex = raw
            }
        }
        
        currentIndex = nextIndex
        loadAndPlay(song: queue[nextIndex])
    }
    
    func previousTrack() {
        guard !queue.isEmpty else { return }
        
        // 如果当前播放超过 3 秒，按上一首返回当前歌曲开头
        if currentTime > 3 {
            player?.seek(to: .zero)
            currentTime = 0
            progress = 0
            return
        }
        
        let prevIndex: Int
        if isShuffleOn {
            ensureShuffledOrder()
            if shuffledPointer > 0 {
                shuffledPointer -= 1
                prevIndex = shuffledOrder[shuffledPointer]
            } else {
                prevIndex = currentIndex
            }
        } else {
            prevIndex = (currentIndex - 1 + queue.count) % queue.count
        }
        
        currentIndex = prevIndex
        loadAndPlay(song: queue[prevIndex])
    }
    
    func seek(to progress: Double) {
        guard let player = player else {
            print("⚠️ seek 失败: player 为 nil")
            return
        }
        // 如果 duration 还没加载，从 currentItem 读取
        let effectiveDuration: TimeInterval
        if duration > 0 {
            effectiveDuration = duration
        } else if let itemDuration = player.currentItem?.duration, itemDuration.isValid {
            let d = CMTimeGetSeconds(itemDuration)
            effectiveDuration = (d.isFinite && !d.isNaN && d > 0) ? d : 0
            self.duration = effectiveDuration
        } else {
            effectiveDuration = 0
        }
        guard effectiveDuration > 0 else {
            print("⚠️ seek 失败: duration=0")
            return
        }
        
        let clampedProgress = max(0, min(1, progress))
        let targetSeconds = effectiveDuration * clampedProgress
        let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        
        // 递增代际 + 更新时间戳，立即锁住 observer
        seekGeneration &+= 1
        lastSeekWallTime = Date()
        
        // 立即更新 UI，不让用户看到回弹
        currentTime = targetSeconds
        self.progress = clampedProgress
        
        print("⏩ seek #\(seekGeneration): \(String(format: "%.1f", clampedProgress * 100))% → \(Int(targetSeconds))s / \(Int(effectiveDuration))s")
        
        let thisGeneration = seekGeneration
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                guard let self = self else { return }
                print("⏩ seek #\(thisGeneration) 回调: finished=\(finished), 当前代际=\(self.seekGeneration)")
                // 不主动解锁，靠时间戳 1.5 秒后自然解锁
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadAndPlay(song: Song) {
        currentSong = song
        stopPreviousPlayer()
        
        if let assetURL = song.assetURL {
            playLocalFile(url: assetURL, song: song)
        } else {
            // 示例音频（无真实文件）
            playbackState = .paused
            duration = song.duration
            progress = 0
            errorMessage = nil
        }
    }
    
    private func playLocalFile(url: URL, song: Song) {
        print("🎵 正在尝试播放: \(url.path)")
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            errorMessage = "音频文件不存在: \(url.lastPathComponent)"
            print("❌ \(errorMessage ?? "")")
            return
        }
        
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = volume
        
        self.player = newPlayer
        self.playerItem = item
        
        // 监听时长
        item.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            Task { @MainActor in
                let duration = item.duration.isValid ? CMTimeGetSeconds(item.duration) : 0
                let safeDuration = duration.isFinite && !duration.isNaN ? duration : 0
                self?.duration = safeDuration
                print("⏱ 时长: \(safeDuration) 秒")
            }
        }
        
        // 监听播放结束
        finishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackFinished()
            }
        }
        
        // 监听播放时间
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                // seek 后 1.5 秒内忽略 observer 更新，防止旧值覆盖拖拽位置
                let elapsed = Date().timeIntervalSince(self.lastSeekWallTime)
                if elapsed < 1.5 {
                    return
                }
                let seconds = CMTimeGetSeconds(time)
                guard seconds.isFinite, !seconds.isNaN else { return }
                self.currentTime = seconds
                if self.duration > 0 {
                    self.progress = self.currentTime / self.duration
                }
            }
        }
        
        newPlayer.play()
        playbackState = .playing
        print("✅ 播放成功: \(url.lastPathComponent)")
    }
    
    private func stopPreviousPlayer() {
        player?.pause()
        removeObservers()
        player = nil
        playerItem = nil
        currentTime = 0
        progress = 0
        seekGeneration &+= 1
        lastSeekWallTime = .distantPast
    }
    
    private func removeObservers() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = finishObserver {
            NotificationCenter.default.removeObserver(observer)
            finishObserver = nil
        }
    }
    
    private func handlePlaybackFinished() {
        advanceToNext(userInitiated: false)
    }
    
    // MARK: - Repeat / Shuffle / Volume
    func toggleShuffle() {
        isShuffleOn.toggle()
        if isShuffleOn {
            reshuffleQueue()
        } else {
            shuffledOrder = []
            shuffledPointer = 0
        }
    }
    
    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    // MARK: - Shuffle Helpers
    private func ensureShuffledOrder() {
        if shuffledOrder.isEmpty {
            reshuffleQueue()
        }
    }
    
    private func reshuffleQueue() {
        var indices = Array(0..<queue.count)
        // Fisher-Yates 打乱，确保当前歌曲排在第一位
        indices.shuffle()
        if let pos = indices.firstIndex(of: currentIndex) {
            indices.swapAt(0, pos)
        }
        shuffledOrder = indices
        shuffledPointer = 0
    }
}
