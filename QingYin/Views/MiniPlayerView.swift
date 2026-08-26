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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(songArtColor(for: song))
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(QingYinColors.ink)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 12))
                            .foregroundColor(QingYinColors.inkMist)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: playerViewModel.togglePlayPause) {
                        Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(QingYinColors.cobalt)
                            .frame(width: 36, height: 36)
                            .background(QingYinColors.cobalt.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button(action: playerViewModel.next) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(QingYinColors.inkLight)
                            .frame(width: 32, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    glassBackground
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: QingYinColors.ink.opacity(0.10), radius: 14, y: 5)
                .onTapGesture {
                    playerViewModel.isNowPlayingPresented = true
                }
            }
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.clear)
                .glassEffect()
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private func songArtColor(for song: Song) -> Color {
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
