//
//  SettingsView.swift
//  设置页面
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var autoPlay = true
    @State private var crossfade = false
    @State private var showLyrics = true
    
    var body: some View {
        ZStack {
            QingYinColors.porcelain.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Text("设置")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(QingYinColors.ink)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                List {
                    Section(header: Text("播放").foregroundColor(QingYinColors.inkMist)) {
                        Toggle("自动播放", isOn: $autoPlay)
                        Toggle("淡入淡出", isOn: $crossfade)
                        Toggle("显示歌词", isOn: $showLyrics)
                    }
                    
                    Section(header: Text("资料库").foregroundColor(QingYinColors.inkMist)) {
                        Button(action: { libraryViewModel.requestLibraryAccess() }) {
                            HStack {
                                Text("访问系统音乐库")
                                    .foregroundColor(QingYinColors.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                        }
                        
                        if libraryViewModel.isAuthorized {
                            HStack {
                                Text("已授权访问")
                                    .foregroundColor(QingYinColors.celadon)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(QingYinColors.celadon)
                            }
                        }
                    }
                    
                    #if os(macOS)
                    Section(header: Text("Apple Music").foregroundColor(QingYinColors.inkMist)) {
                        Button(action: { libraryViewModel.requestLibraryAccess() }) {
                            HStack {
                                Text("扫描 Apple Music 本地音乐")
                                    .foregroundColor(QingYinColors.ink)
                                Spacer()
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(QingYinColors.cobalt)
                            }
                        }
                    }
                    #endif
                    
                    Section(header: Text("同步").foregroundColor(QingYinColors.inkMist)) {
                        Button(action: { libraryViewModel.restoreFromiCloud() }) {
                            HStack {
                                Text("从 iCloud 恢复播放列表")
                                    .foregroundColor(QingYinColors.ink)
                                Spacer()
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(QingYinColors.cobalt)
                            }
                        }
                    }
                    
                    Section(header: Text("关于").foregroundColor(QingYinColors.inkMist)) {
                        HStack {
                            Text("版本")
                                .foregroundColor(QingYinColors.ink)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(QingYinColors.inkMist)
                        }
                    }
                }
                .listStyle(.plain)
                .background(QingYinColors.porcelain)
            }
        }
    }
}
