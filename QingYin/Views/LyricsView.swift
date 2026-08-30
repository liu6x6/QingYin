//
//  LyricsView.swift
//  歌词显示视图
//

import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @State private var parsedLyrics: [LyricsLine] = []
    @State private var currentIndex: Int? = nil
    
    private var lyricsText: String? {
        playerViewModel.currentLyrics ?? playerViewModel.currentSong?.lyrics
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            HStack {
                Text("歌词")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(QingYinColors.ink)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // 歌词内容
            if parsedLyrics.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    if playerViewModel.isLyricsLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("搜索歌词中...")
                            .font(.system(size: 13))
                            .foregroundColor(QingYinColors.inkMist)
                    } else {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(QingYinColors.cobalt.opacity(0.3))
                        Text("暂无歌词")
                            .font(.system(size: 14))
                            .foregroundColor(QingYinColors.inkMist)
                    }
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(parsedLyrics.enumerated()), id: \.element.id) { index, line in
                                Text(line.text)
                                    .font(.system(size: 15, weight: index == currentIndex ? .semibold : .regular))
                                    .foregroundColor(index == currentIndex ? QingYinColors.cobalt : QingYinColors.inkMist)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.horizontal, 32)
                                    .id(index)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .onChange(of: currentIndex) { newIndex in
                        if let newIndex = newIndex {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(QingYinColors.porcelain)
        .onAppear {
            loadLyrics()
        }
        .onChange(of: playerViewModel.currentSong) { _ in
            loadLyrics()
        }
        .onChange(of: playerViewModel.currentLyrics) { _ in
            loadLyrics()
        }
        .onReceive(playerViewModel.player.$currentTime) { time in
            updateCurrentIndex(time: time)
        }
    }
    
    private func loadLyrics() {
        if let lyrics = lyricsText, !lyrics.isEmpty {
            parsedLyrics = LyricsParser.parse(lyrics)
        } else {
            parsedLyrics = []
        }
        currentIndex = parsedLyrics.currentIndex(at: playerViewModel.player.currentTime)
    }
    
    private func updateCurrentIndex(time: TimeInterval) {
        currentIndex = parsedLyrics.currentIndex(at: time)
    }
}
