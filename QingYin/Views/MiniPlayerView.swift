//
//  MiniPlayerView.swift
//  迷你播放器
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        Group {
            if let song = playerViewModel.currentSong {
                HStack(spacing: 10) {
                    // 封面
                    RoundedRectangle(cornerRadius: 6)
                        .fill(QingYinColors.cobaltPale)
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
                        )
                    
                    // 信息
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(QingYinColors.cobalt)
                        Text(song.artist)
                            .font(.system(size: 10))
                            .foregroundColor(QingYinColors.inkMist)
                    }
                    
                    Spacer()
                    
                    // 控制按钮
                    Button(action: playerViewModel.previous) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(QingYinColors.inkLight)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: playerViewModel.togglePlayPause) {
                        Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(QingYinColors.cobalt)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: playerViewModel.next) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(QingYinColors.inkLight)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(QingYinColors.cobaltGhost)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(QingYinColors.cobalt.opacity(0.10), lineWidth: 1)
                )
                .cornerRadius(8)
                .onTapGesture {
                    playerViewModel.isNowPlayingPresented = true
                }
            }
        }
    }
}
