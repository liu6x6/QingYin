//
//  QueueView.swift
//  播放队列（支持拖拽排序）
//

import SwiftUI

struct QueueView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()
                
                List {
                    ForEach(Array(playerViewModel.player.queue.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12))
                                .foregroundColor(QingYinColors.inkMist)
                                .frame(width: 24, alignment: .center)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(QingYinColors.cobaltPale)
                                .frame(width: 36, height: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.system(size: 14, weight: index == playerViewModel.player.currentIndex ? .semibold : .regular))
                                    .foregroundColor(index == playerViewModel.player.currentIndex ? QingYinColors.cobalt : QingYinColors.ink)
                                Text(song.artist)
                                    .font(.system(size: 12))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                            
                            Spacer()
                            
                            if index == playerViewModel.player.currentIndex {
                                HStack(spacing: 2) {
                                    ForEach(0..<4) { i in
                                        EQBar(index: i)
                                    }
                                }
                            } else {
                                Text(song.formattedDuration)
                                    .font(.system(size: 12))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(QingYinColors.porcelain)
                        .listRowSeparator(.hidden)
                    }
                    .onMove { source, destination in
                        playerViewModel.player.moveQueueItem(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .background(QingYinColors.porcelain)
            }
            .navigationTitle("播放队列")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(QingYinColors.cobalt)
                }
            }
        }
    }
}
