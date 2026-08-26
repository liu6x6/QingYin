//
//  AudioPlayerManager.swift
//  本地音频播放与均衡器核心
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

    @Published var currentSong: Song?
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var queue: [Song] = []
    @Published var currentIndex: Int = 0
    @Published var isShuffleOn = false
    @Published var repeatMode: RepeatMode = .off
    @Published var volume: Float = 1
    @Published private(set) var equalizerSettings: EqualizerSettings
    @Published var errorMessage: String?
    var isRestoring = false

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: EqualizerSettings.frequencies.count)
    private var scheduledFile: AVAudioFile?
    private var scheduleGeneration = 0
    private var startedAt = Date.distantPast
    private var scheduledStartTime: TimeInterval = 0
    private var lastProgressSaveAt = Date.distantPast
    /// 恢复后保护期：防止重置的 0s 覆盖已保存的有效位置
    private var saveProtectionUntil = Date.distantPast
    private var playbackTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var shuffledOrder: [Int] = []
    private var shuffledPointer = 0

    private enum PersistenceKey: String {
        case lastPlayedSongID = "qingyin.lastPlayedSongID"
        case lastPlayedTime = "qingyin.lastPlayedTime"
        case isShuffleOn = "qingyin.isShuffleOn"
        case repeatMode = "qingyin.repeatMode"
        case equalizerSettings = "qingyin.equalizerSettings"
    }

    private init() {
        equalizerSettings = Self.loadEqualizerSettings()
        configureAudioGraph()
        setupAudioSession()
        applyEqualizerSettings()

        $volume
            .dropFirst()
            .sink { [weak self] newVolume in
                self?.engine.mainMixerNode.outputVolume = newVolume
            }
            .store(in: &cancellables)

        $currentSong
            .compactMap(\.?.id)
            .sink { UserDefaults.standard.set($0.uuidString, forKey: PersistenceKey.lastPlayedSongID.rawValue) }
            .store(in: &cancellables)

        $playbackState
            .sink { [weak self] state in
                if state != .playing {
                    self?.saveCurrentTime()
                }
            }
            .store(in: &cancellables)

        // 每 5 秒定期保存播放位置（播放中）
        $currentTime
            .throttle(for: .seconds(5), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self = self, playbackState == .playing else { return }
                saveCurrentTime()
            }
            .store(in: &cancellables)

        isShuffleOn = UserDefaults.standard.bool(forKey: PersistenceKey.isShuffleOn.rawValue)
        if let rawValue = UserDefaults.standard.string(forKey: PersistenceKey.repeatMode.rawValue),
           let savedMode = RepeatMode(rawValue: rawValue) {
            repeatMode = savedMode
        }
        $isShuffleOn
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: PersistenceKey.isShuffleOn.rawValue) }
            .store(in: &cancellables)
        $repeatMode
            .dropFirst()
            .map(\.rawValue)
            .sink { UserDefaults.standard.set($0, forKey: PersistenceKey.repeatMode.rawValue) }
            .store(in: &cancellables)

        playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updatePlaybackProgress() }

        #if os(macOS)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.saveCurrentTime() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.saveCurrentTime() }
            .store(in: &cancellables)
        #else
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.saveCurrentTime() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.saveCurrentTime() }
            .store(in: &cancellables)
        #endif
    }

    func restoreLastPlayed(from songs: [Song]) {
        guard currentSong == nil,
              let identifier = UserDefaults.standard.string(forKey: PersistenceKey.lastPlayedSongID.rawValue),
              let songID = UUID(uuidString: identifier),
              let song = songs.first(where: { $0.id == songID }) else {
            print("⚠️ restoreLastPlayed: 无可恢复的歌曲")
            return
        }

        let savedTime = UserDefaults.standard.double(forKey: PersistenceKey.lastPlayedTime.rawValue)
        print("🔄 restoreLastPlayed: \(song.title), savedTime=\(Int(savedTime))s")

        isRestoring = true
        defer { isRestoring = false }
        // 3秒保护期，防止后续重置覆盖有效位置
        saveProtectionUntil = Date().addingTimeInterval(3)
        queue = songs
        currentIndex = songs.firstIndex(where: { $0.id == song.id }) ?? 0
        currentSong = song
        load(song: song, at: savedTime, shouldPlay: false)
    }

    func play(song: Song, queue: [Song] = []) {
        print("▶️ play() called: \(song.title), currentTime=\(Int(currentTime))s, currentSong=\(currentSong?.title ?? "nil")")
        // 如果播放的就是当前歌曲且时间 > 0（恢复状态），直接继续播放
        if currentSong?.id == song.id && currentTime > 0 {
            print("▶️ 同一首歌，从 \(Int(currentTime))s 继续播放")
            self.queue = queue.isEmpty ? self.queue : queue
            resume()
            return
        }
        self.queue = queue.isEmpty ? [song] : queue
        currentIndex = self.queue.firstIndex(where: { $0.id == song.id }) ?? 0
        if isShuffleOn {
            reshuffleQueue()
        }
        load(song: song, at: 0, shouldPlay: true)
    }

    func addToQueueNext(_ song: Song) {
        queue.insert(song, at: min(currentIndex + 1, queue.count))
    }

    func moveQueueItem(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
    }

    func togglePlayPause() {
        print("⏯ togglePlayPause called, state=\(playbackState), currentTime=\(Int(currentTime))s")
        switch playbackState {
        case .playing: pause()
        case .paused, .stopped:
            guard currentSong != nil else { return }
            resume()
        }
    }

    func pause() {
        updatePlaybackProgress()
        playerNode.pause()
        playbackState = .paused
    }

    func resume() {
        print("▶️ resume() called, currentTime=\(Int(currentTime))s, scheduledFile=\(scheduledFile != nil)")
        guard scheduledFile != nil else { return }
        guard startEngine() else { return }
        playerNode.stop()
        scheduleCurrentFile(from: currentTime)
        playerNode.play()
        startedAt = Date()
        scheduledStartTime = currentTime
        playbackState = .playing
    }

    func stop() {
        playerNode.stop()
        scheduledFile = nil
        scheduleGeneration &+= 1
        playbackState = .stopped
        currentTime = 0
        progress = 0
    }

    func nextTrack() {
        advanceToNext(userInitiated: true)
    }

    func previousTrack() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        let previousIndex: Int
        if isShuffleOn {
            ensureShuffledOrder()
            if shuffledPointer > 0 {
                shuffledPointer -= 1
            }
            previousIndex = shuffledOrder[shuffledPointer]
        } else {
            previousIndex = (currentIndex - 1 + queue.count) % queue.count
        }
        currentIndex = previousIndex
        load(song: queue[previousIndex], at: 0, shouldPlay: true)
    }

    func seek(to progress: Double) {
        guard duration > 0, scheduledFile != nil else { return }
        let targetTime = duration * max(0, min(1, progress))
        let wasPlaying = playbackState == .playing
        playerNode.stop()
        scheduleCurrentFile(from: targetTime)
        currentTime = targetTime
        self.progress = targetTime / duration
        scheduledStartTime = targetTime
        if wasPlaying {
            playerNode.play()
            startedAt = Date()
        }
    }

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

    func setEqualizerEnabled(_ isEnabled: Bool) {
        equalizerSettings.isEnabled = isEnabled
        applyEqualizerSettings()
        saveEqualizerSettings()
    }

    func selectEqualizerPreset(_ preset: EqualizerPreset) {
        guard preset != .custom else { return }
        equalizerSettings = EqualizerSettings.presetSettings(for: preset)
        applyEqualizerSettings()
        saveEqualizerSettings()
    }

    func setEqualizerGain(_ gain: Float, at index: Int) {
        guard equalizerSettings.bands.indices.contains(index) else { return }
        equalizerSettings.bands[index].gain = EqualizerBand.clamp(gain)
        equalizerSettings.preset = .custom
        applyEqualizerSettings()
        saveEqualizerSettings()
    }

    func setPreampGain(_ gain: Float) {
        equalizerSettings.preampGain = EqualizerSettings.clampPreamp(gain)
        equalizerSettings.preset = .custom
        applyEqualizerSettings()
        saveEqualizerSettings()
    }

    func resetEqualizer() {
        equalizerSettings = EqualizerSettings.presetSettings(for: .flat)
        applyEqualizerSettings()
        saveEqualizerSettings()
    }

    private func configureAudioGraph() {
        engine.attach(playerNode)
        engine.attach(equalizer)
        engine.connect(playerNode, to: equalizer, format: nil)
        engine.connect(equalizer, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = volume
    }

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

    private func load(song: Song, at time: TimeInterval, shouldPlay: Bool) {
        print("🎵 load: \(song.title), at=\(Int(time))s, shouldPlay=\(shouldPlay), duration=\(Int(duration))s")
        guard let url = song.assetURL else {
            currentSong = song
            duration = song.duration
            currentTime = 0
            progress = 0
            playbackState = .paused
            errorMessage = "示例歌曲没有可播放的本地音频文件。"
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "音频文件不存在: \(url.lastPathComponent)"
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else {
                errorMessage = "无法读取音频采样率: \(url.lastPathComponent)"
                return
            }

            playerNode.stop()
            scheduleGeneration &+= 1
            scheduledFile = file
            currentSong = song
            duration = Double(file.length) / sampleRate
            currentTime = min(max(0, time), duration)
            progress = duration > 0 ? currentTime / duration : 0
            scheduledStartTime = currentTime
            scheduleCurrentFile(from: currentTime)

            if shouldPlay {
                guard startEngine() else { return }
                playerNode.play()
                startedAt = Date()
                playbackState = .playing
            } else {
                playbackState = .paused
            }
            errorMessage = nil
        } catch {
            errorMessage = "无法播放 \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func scheduleCurrentFile(from time: TimeInterval) {
        guard let file = scheduledFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(min(Double(file.length), max(0, time * sampleRate)))
        let remainingFrames = file.length - startFrame
        guard remainingFrames > 0 else {
            handlePlaybackFinished()
            return
        }

        scheduleGeneration &+= 1
        let generation = scheduleGeneration
        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(remainingFrames),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.scheduleGeneration == generation else { return }
                self?.handlePlaybackFinished()
            }
        }
    }

    private func startEngine() -> Bool {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "无法激活音频会话: \(error.localizedDescription)"
            return false
        }
        #endif
        guard !engine.isRunning else { return true }
        do {
            engine.prepare()
            try engine.start()
            return true
        } catch {
            errorMessage = "音频引擎启动失败: \(error.localizedDescription)"
            return false
        }
    }

    private func updatePlaybackProgress() {
        guard playbackState == .playing, duration > 0 else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        currentTime = min(duration, scheduledStartTime + elapsed)
        progress = currentTime / duration
        if Date().timeIntervalSince(lastProgressSaveAt) >= 5 {
            saveCurrentTime()
            lastProgressSaveAt = Date()
        }    }

    private func advanceToNext(userInitiated: Bool) {
        print("⏭ advanceToNext called, userInitiated=\(userInitiated), repeatMode=\(repeatMode)")
        guard !queue.isEmpty else { return }
        if repeatMode == .one && !userInitiated {
            load(song: queue[currentIndex], at: 0, shouldPlay: true)
            return
        }

        let nextIndex: Int
        if isShuffleOn {
            ensureShuffledOrder()
            if shuffledPointer < shuffledOrder.count - 1 {
                shuffledPointer += 1
            } else if repeatMode == .all {
                reshuffleQueue()
            } else {
                playbackState = .paused
                return
            }
            nextIndex = shuffledOrder[shuffledPointer]
        } else {
            let candidate = currentIndex + 1
            if candidate >= queue.count {
                guard repeatMode == .all else {
                    playbackState = .paused
                    currentTime = duration
                    progress = 1
                    return
                }
                nextIndex = 0
            } else {
                nextIndex = candidate
            }
        }
        currentIndex = nextIndex
        load(song: queue[nextIndex], at: 0, shouldPlay: true)
    }

    private func handlePlaybackFinished() {
        guard playbackState == .playing || currentTime >= duration else { return }
        advanceToNext(userInitiated: false)
    }

    private func ensureShuffledOrder() {
        if shuffledOrder.isEmpty {
            reshuffleQueue()
        }
    }

    private func reshuffleQueue() {
        var indices = Array(queue.indices)
        indices.shuffle()
        if let currentPosition = indices.firstIndex(of: currentIndex) {
            indices.swapAt(0, currentPosition)
        }
        shuffledOrder = indices
        shuffledPointer = 0
    }

    private func applyEqualizerSettings() {
        equalizer.globalGain = equalizerSettings.preampGain
        equalizer.bypass = !equalizerSettings.isEnabled
        for (index, band) in equalizerSettings.bands.enumerated() where equalizer.bands.indices.contains(index) {
            let filter = equalizer.bands[index]
            filter.filterType = .parametric
            filter.frequency = band.frequency
            filter.bandwidth = 1
            filter.gain = band.gain
            filter.bypass = false
        }
    }

    private func saveCurrentTime() {
        let time = currentTime
        // 恢复保护期内，不保存 0s
        if Date() < saveProtectionUntil && time < 1 {
            print("💾 saveCurrentTime: SKIPPED (保护期)")
            return
        }
        // 核心保护：永远不要用 0s 覆盖已有的有效位置（歌曲播完后 currentTime 重置为 0）
        if time < 1 {
            let saved = UserDefaults.standard.double(forKey: PersistenceKey.lastPlayedTime.rawValue)
            if saved > 1 {
                print("💾 saveCurrentTime: SKIPPED (0s 不覆盖已保存的 \(Int(saved))s)")
                return
            }
        }
        UserDefaults.standard.set(time, forKey: PersistenceKey.lastPlayedTime.rawValue)
        print("💾 saveCurrentTime: \(Int(time))s")
    }

    private func saveEqualizerSettings() {
        guard let data = try? JSONEncoder().encode(equalizerSettings) else { return }
        UserDefaults.standard.set(data, forKey: PersistenceKey.equalizerSettings.rawValue)
    }

    private static func loadEqualizerSettings() -> EqualizerSettings {
        guard let data = UserDefaults.standard.data(forKey: PersistenceKey.equalizerSettings.rawValue),
              let settings = try? JSONDecoder().decode(EqualizerSettings.self, from: data) else {
            return .default
        }
        return settings
    }
}
