# 清音 (QingYin)

跨平台音乐播放器 — iOS / iPadOS / macOS，青花瓷主题设计。

## 项目结构

```
QingYin/
├── QingYin/
│   ├── QingYinApp.swift              # App 入口
│   ├── Info.plist                    # 应用配置
│   ├── QingYin.entitlements          # iCloud 权限
│   ├── Models/
│   │   ├── Song.swift                # 歌曲模型
│   │   └── Playlist.swift            # 播放列表模型
│   ├── Services/
│   │   ├── AudioPlayerManager.swift  # 音频播放核心
│   │   ├── MusicLibraryService.swift # 系统音乐库访问
│   │   ├── LocalFileService.swift    # 本地音频文件导入
│   │   ├── LyricsParser.swift       # LRC 歌词解析
│   │   └── iCloudSyncService.swift  # iCloud 同步
│   ├── ViewModels/
│   │   ├── PlayerViewModel.swift     # 播放器视图模型
│   │   └── LibraryViewModel.swift    # 音乐库视图模型
│   ├── Views/
│   │   ├── ContentView.swift         # 主入口
│   │   ├── LibraryView.swift         # 音乐库
│   │   ├── NowPlayingView.swift      # 正在播放
│   │   ├── LyricsView.swift         # 歌词
│   │   ├── QueueView.swift          # 播放队列
│   │   ├── PlaylistView.swift        # 播放列表
│   │   ├── SearchView.swift          # 搜索
│   │   ├── SettingsView.swift        # 设置
│   │   ├── AlbumListView.swift       # 专辑/艺术家
│   │   └── MiniPlayerView.swift      # 迷你播放器
│   ├── Utilities/
│   │   └── QingYinColors.swift       # 青花瓷色板
│   └── Resources/
│       └── Assets.xcassets/          # 图标与颜色资源
├── QingYinTests/
├── QingYinUITests/
├── project.yml                       # XcodeGen 配置文件
├── setup.sh                          # 一键设置脚本
├── README.md                         # 说明文档
└── QingYin.xcodeproj                 # Xcode 工程
```

## 环境要求

- Xcode 15+
- iOS 16+ / macOS 13+
- Swift 6.0

## 快速开始

### 方式一：使用 XcodeGen 自动生成工程

1. 安装 XcodeGen（如果还没有）：

```bash
brew install xcodegen
```

2. 生成 Xcode 工程：

```bash
cd /Users/liuxiaolong/2026/QingYin
xcodegen generate
```

3. 打开工程：

```bash
open QingYin.xcodeproj
```

### 方式二：手动创建 Xcode 工程

1. 打开 Xcode
2. 创建新工程：File > New > Project
3. 选择 iOS App 或 macOS App
4. 命名工程为 "QingYin"，Bundle Identifier: `com.qingyin.app`
5. 将 `QingYin/QingYin/` 下的所有文件拖入 Xcode
6. 添加所需 Framework：
   - AVFoundation
   - MediaPlayer
7. 设置最低版本：iOS 16.0 / macOS 13.0
8. 编译运行

## 功能特性

- 播放本地音乐文件
- 读取系统音乐库（需授权）
- 导入本地音频文件（MP3 / M4A / WAV / FLAC / AIFF / OGG）
- 同步 LRC 歌词显示
- 歌曲搜索
- 播放列表管理
- iCloud 同步播放列表
- AirDrop 分享音乐文件
- macOS 菜单栏 + 全局快捷键
- 青花瓷中国风界面
- 跨平台：iPhone / iPad / Mac

## 色彩系统

| 名称 | 色值 | 用途 |
|------|------|------|
| 瓷白 | `#F8F4EC` | 主背景 |
| 钴蓝 | `#1A4B8C` | 主强调色 |
| 青瓷 | `#6A9E96` | 次要强调 |
| 墨色 | `#2A2A2A` | 主要文字 |

## 快捷键（macOS）

| 快捷键 | 功能 |
|--------|------|
| `Space` | 播放 / 暂停 |
| `←` | 上一首 |
| `→` | 下一首 |

## 注意事项

- 首次运行需要在 `设置` 页面点击 `访问系统音乐库` 授权
- 部分 Apple Music 订阅歌曲受 DRM 保护，无法直接播放
- 测试数据在 DEBUG 模式下自动加载
- 启用 iCloud 同步需要在 Xcode 中勾选 iCloud capability 并配置 entitlements

## 下一步计划

- [ ] 播放历史
- [ ] 收藏歌曲
- [x] 均衡器 / 音效
- [ ] 睡眠定时器

## 设计文档

- [均衡器设计方案与界面设计稿](docs/equalizer-design.md)
- [均衡器界面设计稿（SVG）](docs/equalizer-design.svg)
- [均衡器工作原理](docs/equalizer-principles.md)
