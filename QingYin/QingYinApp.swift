//
//  QingYinApp.swift
//  清音 — 青花瓷音乐播放器
//

import SwiftUI

@main
struct QingYinApp: App {
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @State private var hasRestoredLastPlayed = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerViewModel)
                .environmentObject(libraryViewModel)
                .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                    // 歌曲列表加载后，恢复上次播放的歌曲
                    guard !hasRestoredLastPlayed else { return }
                    let allSongs = libraryViewModel.allSongs
                    guard !allSongs.isEmpty else { return }
                    hasRestoredLastPlayed = true
                    AudioPlayerManager.shared.restoreLastPlayed(from: allSongs)
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
        .commands {
            CommandMenu("播放") {
                Button("播放 / 暂停") {
                    playerViewModel.togglePlayPause()
                }
                .keyboardShortcut(" ", modifiers: [])
                
                Button("上一首") {
                    playerViewModel.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Button("下一首") {
                    playerViewModel.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }
    }
}
