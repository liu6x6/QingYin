# 清音 (QingYin) — 项目 Wiki

> macOS / iOS 青花瓷风格音乐播放器  
> SwiftUI + AVFoundation  
> 最低版本: macOS 13.0 / iOS 16.0

---

## 目录

1. [项目概述](#1-项目概述)
2. [架构设计](#2-架构设计)
3. [目录结构](#3-目录结构)
4. [数据模型](#4-数据模型)
5. [Services 层](#5-services-层)
6. [ViewModels 层](#6-viewmodels-层)
7. [Views 层](#7-views-层)
8. [持久化策略](#8-持久化策略)
9. [色彩系统](#9-色彩系统)
10. [构建与部署](#10-构建与部署)
11. [已知限制与 TODO](#11-已知限制与-todo)

---

## 1. 项目概述

**清音** 是一款以青花瓷为设计语言的本地音乐播放器，支持 macOS 原生和 iOS（含 Mac Catalyst）双平台。

### 核心功能

| 功能 | 说明 |
|------|------|
| 本地文件播放 | 导入 mp3/m4a/aac/wav/aiff/flac/ogg 文件，基于 AVPlayer 播放 |
| 系统音乐库 | iOS 端可读取 Apple Music 本地歌曲 |
| macOS 目录扫描 | 扫描 `~/Music` 目录下的音频文件 |
| 拖拽导入 | 从 Finder 拖拽音频文件到 APP 窗口，单文件自动播放 |
| 歌曲列表 | 自定义表头、可拖拽列排序、列宽调整、弹性列自适应窗口 |
| 播放控制 | 单击选中、双击播放、播放/暂停/上一首/下一首 |
| 进度条 | 实时进度显示、拖拽调整进度（带把手）、hover 反馈 |
| 随机播放 | Fisher-Yates 打乱顺序，支持上一首回退 |
| 循环模式 | 关闭 / 列表循环 / 单曲循环 三态切换 |
| 喜欢 | 收藏歌曲，持久化到 UserDefaults + iCloud |
| 播放列表 | 创建/管理播放列表，歌曲按 ID 关联 |
| 歌词 | LRC 歌词解析与同步显示 |
| 歌词自动搜索 | 基于 LRCLIB API 在线搜索歌词，本地缓存 |
| 音量控制 | 拖拽式音量条 |
| 搜索 | 按标题/艺术家/专辑实时筛选 |
| 启动恢复 | 下次打开自动选中上次播放的歌曲和时间 |
| 键盘快捷键 | 空格播放/暂停、← 上一首、→ 下一首 |

### 技术栈

| 技术 | 用途 |
|------|------|
| SwiftUI | 全平台 UI 框架 |
| AVFoundation (AVAudioEngine) | 音频播放引擎 |
| Combine | 响应式状态管理、属性转发 |
| MediaPlayer (iOS) | 系统音乐库访问 |
| UniformTypeIdentifiers | 文件导入/拖拽类型匹配 |
| CloudKit (NSUbiquitousKeyValueStore) | iCloud 轻量数据同步 |
| UserDefaults | 本地持久化（喜欢、播放列表、播放位置、设置） |
| XcodeGen (project.yml) | Xcode 项目生成 |

---

## 2. 架构设计

### 整体架构: MVVM

```
┌─────────────────────────────────────────────────┐
│                   QingYinApp                     │
│         (App 入口, EnvironmentObject 注入)        │
└─────────────┬───────────────────┬───────────────┘
              │                   │
              ▼                   ▼
┌─────────────────────┐  ┌──────────────────────┐
│   PlayerViewModel   │  │   LibraryViewModel   │
│  (播放状态代理)       │  │  (歌曲/列表数据代理)   │
└──────────┬──────────┘  └──────────┬───────────┘
           │                        │
           ▼                        ▼
┌─────────────────────┐  ┌──────────────────────┐
│ AudioPlayerManager  │  │  LocalFileService    │
│   (AVPlayer 单例)    │  │  MusicLibraryService │
│                     │  │  AppleMusicMacService │
│                     │  │  iCloudSyncService    │
└─────────────────────┘  └──────────────────────┘
```

### 数据流

1. **View → ViewModel → Service**: 用户操作触发 ViewModel 方法，ViewModel 调用 Service 执行业务逻辑
2. **Service → ViewModel → View**: Service 的 `@Published` 属性变化，ViewModel 通过 Combine `assign(to:)` 转发，SwiftUI 自动刷新 View
3. **AudioPlayerManager 是单例** (`AudioPlayerManager.shared`)，全局唯一，PlayerViewModel 持有引用并转发其 `@Published` 属性

### 环境对象注入

```swift
// QingYinApp.swift
ContentView()
    .environmentObject(playerViewModel)   // PlayerViewModel
    .environmentObject(libraryViewModel)  // LibraryViewModel
```

所有 View 通过 `@EnvironmentObject` 访问这两个 ViewModel。

---

## 3. 目录结构

```
QingYin/
├── QingYinApp.swift                 # App 入口，Scene 配置，启动恢复逻辑
│
├── Models/
│   ├── Song.swift                   # 歌曲模型 + 稳定 ID 生成器
│   └── Playlist.swift               # 播放列表模型
│
├── Services/
│   ├── AudioPlayerManager.swift     # 音频播放核心（AVAudioEngine 单例）
│   ├── LocalFileService.swift       # 本地文件导入、扫描、删除
│   ├── MusicLibraryService.swift    # iOS 系统音乐库访问
│   ├── AppleMusicMacService.swift   # macOS ~/Music 目录扫描
│   ├── AudioMetadataExtractor.swift # ID3 元数据提取（标题/艺术家/专辑/封面）
│   ├── LyricsParser.swift           # LRC 歌词解析
│   ├── LyricsService.swift          # 歌词在线搜索（LRCLIB）与本地缓存
│   └── iCloudSyncService.swift      # iCloud 同步（播放列表/喜欢）
│
├── ViewModels/
│   ├── PlayerViewModel.swift        # 播放器状态代理，转发 AudioPlayerManager
│   └── LibraryViewModel.swift       # 歌曲库数据管理，筛选/排序/持久化
│
├── Views/
│   ├── ContentView.swift            # 主入口，iOS/macOS 分支
│   ├── MacLibraryView.swift         # macOS 歌曲列表（自定义表头、列宽、拖拽排序）
│   ├── MacPlayerBar.swift           # macOS 底部播放控制条 + ProgressSlider 组件
│   ├── LyricsPanelView.swift        # 全屏歌词面板（左播放器 + 右歌词）
│   ├── EqualizerView.swift          # 十段均衡器调节界面
│   ├── LibraryView.swift            # iOS 歌曲列表
│   ├── MiniPlayerView.swift         # iOS 迷你播放器
│   ├── NowPlayingView.swift         # 全屏正在播放页面
│   ├── AlbumListView.swift          # 专辑列表 + ArtistListView
│   ├── FavoritesView.swift          # 我喜欢的歌曲
│   ├── PlaylistView.swift           # 播放列表网格
│   ├── QueueView.swift              # 播放队列（支持拖拽排序）
│   ├── LyricsView.swift             # 歌词显示（iOS sheet）
│   ├── SearchView.swift             # 搜索页面
│   └── SettingsView.swift           # 设置页面
│
└── Utilities/
    └── QingYinColors.swift          # 青花瓷设计色板
```

---

## 4. 数据模型

### Song

```swift
struct Song: Identifiable, Equatable, Hashable {
    let id: UUID              // 稳定 ID（基于 FNV-1a 哈希，见下方）
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let assetURL: URL?        // 本地文件路径（nil 为示例数据）
    let lyrics: String?       // LRC 歌词原始文本
    let artworkImage: NSImage? / UIImage?  // 封面（平台条件编译）
}
```

**稳定 ID 机制** (`Song.stableID(from:)`):  
使用 FNV-1a 哈希（4 轮 × 16 字节）生成确定性 UUID v5。同一输入永远返回同一 UUID。

| 来源 | ID 输入字符串 |
|------|-------------|
| 本地导入文件 | `"file:{path}"` |
| iOS 系统库 | `"media:{persistentID}"` |
| macOS 扫描 | `"file:{path}"` |
| 示例歌曲 | `"sample:{title}:{artist}"` |

### Playlist

```swift
struct Playlist: Identifiable, Equatable, Codable {
    let id: UUID       // Song.stableID(from: "playlist:{name}")
    var name: String
    var songIDs: [UUID] // 按歌曲 ID 关联，不直接持有 Song
    var createdAt: Date
}
```

---

## 5. Services 层

### AudioPlayerManager（单例）

音频播放核心，基于 `AVAudioEngine + AVAudioPlayerNode + AVAudioUnitEQ`，支持实时均衡器。

| 属性 | 类型 | 说明 |
|------|------|------|
| `currentSong` | `@Published Song?` | 当前歌曲 |
| `playbackState` | `@Published PlaybackState` | .stopped / .playing / .paused |
| `currentTime` | `@Published TimeInterval` | 当前播放时间 |
| `duration` | `@Published TimeInterval` | 歌曲总时长 |
| `progress` | `@Published Double` | 播放进度 0.0~1.0 |
| `queue` | `@Published [Song]` | 播放队列 |
| `currentIndex` | `@Published Int` | 当前在队列中的位置 |
| `isShuffleOn` | `@Published Bool` | 随机播放开关 |
| `repeatMode` | `@Published RepeatMode` | .off / .all / .one |
| `volume` | `@Published Float` | 音量 0.0~1.0 |
| `equalizerSettings` | `@Published EqualizerSettings` | 均衡器设置 |

**核心方法**:

| 方法 | 说明 |
|------|------|
| `play(song:queue:)` | 播放歌曲，设置队列 |
| `togglePlayPause()` | 播放/暂停切换 |
| `nextTrack()` | 下一首（用户主动） |
| `previousTrack()` | 上一首（>3s 重头播放，<3s 跳上一首） |
| `seek(to:)` | 跳转进度（带时间戳锁，1.5s 内屏蔽 observer） |
| `toggleShuffle()` | 切换随机播放（Fisher-Yates 打乱） |
| `cycleRepeatMode()` | 循环模式: off → all → one → off |
| `restoreLastPlayed(from:)` | 恢复上次播放的歌曲和位置 |

**播放引擎**：`AVAudioEngine` + `AVAudioPlayerNode` + `AVAudioUnitEQ`（十段均衡器）。

**Seek 保护机制**:  
`lastSeekWallTime` 时间戳锁 — seek 后 1.5 秒内 periodic observer 不更新 `currentTime`/`progress`，防止旧值覆盖拖拽位置。

**随机播放**:  
维护 `shuffledOrder: [Int]` 和 `shuffledPointer`，按打乱顺序播放，播完重新打乱。

**保存时机**:
- `$currentSong` 变化 → 保存 song ID
- `$playbackState` → paused/stopped → 保存播放时间
- `$currentTime` + `updatePlaybackProgress()` 每 5 秒保存
- APP 关闭/失去焦点通知 → 保存播放时间
- `$isShuffleOn` / `$repeatMode` → 保存设置
- **核心保护**：永远不用 0s 覆盖已有的有效位置（防止歌曲播完后重置覆盖）

### LocalFileService（单例）

本地文件管理。

| 方法 | 说明 |
|------|------|
| `importAudioFile(from:)` | 拷贝文件到 `Documents/Audio/`，同名去重 |
| `importAudioFiles(from:)` | 批量导入 |
| `scanImportedFiles()` | 扫描 Audio 目录重建列表 |
| `deleteImportedSong(_:)` | 删除文件并重新扫描 |

文件存放路径: `Documents/Audio/`  
支持格式: mp3, m4a, aac, wav, aiff, flac, ogg

### MusicLibraryService（单例，iOS）

通过 `MPMediaQuery` 读取 Apple Music 本地歌曲。使用 `persistentID` 生成稳定 ID。

### AppleMusicMacService（单例，macOS）

扫描 `~/Music` 目录下的音频文件，使用文件路径生成稳定 ID。

### AudioMetadataExtractor

从音频文件中提取 ID3 元数据：标题、艺术家、专辑、封面图、时长。

### LyricsParser

解析 LRC 歌词文件，支持 `[mm:ss.xx]` 和 `[mm:ss.xxx]` 时间标签。提供 `currentIndex(at:)` 方法根据播放时间获取当前歌词行。

### iCloudSyncService（单例）

通过 `NSUbiquitousKeyValueStore` 同步轻量数据：播放列表、喜欢列表、上次播放歌曲。

### LyricsService（单例）

歌词在线搜索与本地缓存服务。

**API**: LRCLIB (`https://lrclib.net/api`)，免费开源歌词 API，无需 API Key。

**搜索策略（三级降级）**:
1. 精确匹配: `GET /api/get?artist_name=X&track_name=X`
2. 模糊搜索: `GET /api/search?q={title}`
3. 组合搜索: `GET /api/search?q={title} {artist}`

**缓存层级**:
1. 内存缓存 → APP 运行期间
2. 磁盘缓存 → `Documents/Lyrics/{songID}.lrc`
3. 网络请求 → LRCLIB API

**方法**:

| 方法 | 说明 |
|------|------|
| `getLyrics(for:)` | 获取歌词（缓存优先，自动搜索） |
| `refreshLyrics(for:)` | 强制重新搜索（忽略缓存） |
| `clearCache(for:)` | 删除指定歌曲的歌词缓存 |

---

## 6. ViewModels 层

### PlayerViewModel

播放器状态代理。不持有播放逻辑，而是转发 `AudioPlayerManager` 的属性。

**属性转发** (Combine `assign(to:)`):
```
player.$currentTime  →  $currentTime
player.$duration     →  $duration
player.$progress     →  $progress
player.$volume       →  $volume
player.$isShuffleOn  →  $isShuffleOn
player.$repeatMode   →  $repeatMode
player.$equalizerSettings → $equalizerSettings
```

**歌词自动获取**:
- `@Published currentLyrics: String?` — 当前歌词文本
- `@Published isLyricsLoading: Bool` — 搜索状态
- 歌曲切换时自动调用 `LyricsService.getLyrics(for:)`

**设计原因**: SwiftUI 通过 `@EnvironmentObject` 观察 ViewModel，但不会追踪引用类型（AudioPlayerManager）内部嵌套的 `@Published`。必须在 ViewModel 层显式转发，UI 才能响应变化。

### LibraryViewModel

歌曲库数据管理。

| 属性 | 说明 |
|------|------|
| `songs` | 系统库/扫描歌曲 |
| `playlists` | 播放列表数组 |
| `favoriteIDs` | 喜欢的歌曲 ID 集合 |
| `searchText` | 搜索关键词 |
| `sortKey` / `sortAscending` | 排序设置 |
| `activeFilter` | 筛选: .all / .album / .artist |

**歌曲聚合** (`allSongs`):  
合并 SystemLibrary + LocalImported + Sample，按 ID + 路径双重去重，应用筛选。

**歌曲聚合** (`filteredSongs`):  
在 `allSongs` 上应用搜索文本筛选 + 排序。

**持久化**:
- `init()` 恢复 favoriteIDs 和 playlists
- `$favoriteIDs` 变化自动保存
- 播放列表变更时保存

---

## 7. Views 层

### ContentView

主入口，根据平台分发：
- macOS → `MacContentView` (侧栏 + 内容区 + 底部播放条)
- iOS → `iOSContentView` (TabView)

### MacContentView 布局

```
┌──────────────────────────────────────────────┐
│                MacContentView                │
│  ┌──────────┬───────────────────────────────┐│
│  │          │                               ││
│  │  侧栏    │    selectedContent            ││
│  │  180pt   │    (根据选中项切换)              ││
│  │          │                               ││
│  │ • 歌曲   │                               ││
│  │ • 专辑   │                               ││
│  │ • 艺术家 │                               ││
│  │          │                               ││
│  │ • 列表   │                               ││
│  │ • 喜欢   │                               ││
│  │ • 设置   │                               ││
│  └──────────┴───────────────────────────────┘│
│  ┌──────────────────────────────────────────┐│
│  │            MacPlayerBar                  ││
│  │  封面 | 控制按钮 | 进度条 | 音量          ││
│  └──────────────────────────────────────────┘│
└──────────────────────────────────────────────┘
```

### MacLibraryView（macOS 核心视图）

**布局**:
```
┌─ MacLibraryView ──────────────────────────────┐
│  toolbar (搜索 + 筛选 + 导入按钮)              │
├───────────────────────────────────────────────┤
│  GeometryReader                               │
│  ├─ tableHeader (弹性列宽)                    │
│  └─ songList (ScrollView + LazyVStack)        │
│     └─ MacSongRow × N                        │
├───────────────────────────────────────────────┤
│  bottomBar (状态 / 批量操作)                   │
└───────────────────────────────────────────────┘
```

**列系统**:

| Column | 默认宽度 | 弹性 | 可调整 | 对齐 |
|--------|---------|------|--------|------|
| # (index) | 40pt | ✗ | ✓ | center |
| 标题 (title) | 280pt | ✓ | ✗ | leading |
| 艺术家 (artist) | 140pt | ✗ | ✓ | leading |
| 专辑 (album) | 180pt | ✗ | ✓ | leading |
| 时长 (duration) | 70pt | ✗ | ✓ | trailing |
| 喜欢 (favorite) | 50pt | ✗ | ✗ | center |

- 弹性列（标题）吸收窗口剩余宽度
- 列宽保存到 UserDefaults，跨启动恢复
- 支持拖拽列排序（`DragGesture(minimumDistance: 20)`）

### MacPlayerBar

底部播放控制条。

```
┌─ MacPlayerBar ──────────────────────────────────────────┐
│  [封面 40×40]  歌曲名  |  ⤮ ◀ ⏸ ▶ 🔁  |  [进度条]  |  🔊 [音量]  │
└─────────────────────────────────────────────────────────┘
```

**封面可点击**：hover 时显示蓝色半透明 + 歌词气泡图标，点击触发 `onArtworkTap` 回调打开歌词面板。

**ProgressSlider 组件**（复用于进度条和音量条）:
- 轨道 3pt 高（Capsule 形状）
- 12×12 圆形把手（白色填充 + cobalt 描边 + 阴影）
- 悬停或拖拽时显示把手，平时隐藏
- `.highPriorityGesture` 确保不被父视图吞掉
- `lastSeekValue` 锁定机制防止视觉回弹

### NowPlayingView

全屏正在播放页面（iOS sheet 弹出）。包含：
- 青花瓷风格圆盘封面
- 进度条（ProgressSlider）
- 播放控制按钮组
- 音量控制
- 歌词/队列/分享/收藏底部操作

### LyricsPanelView

全屏歌词面板（macOS），点击底部播放条封面打开。

**布局**：
```
┌─ 全屏覆盖 ────────────────────────────────────────────────┐
│                                                       [↓] │
│                                                           │
│  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │ 封面 240×240  │  │  歌词列表（自动同步滚动）        │  │
│  │              │  │  ▶ 当前行 22pt 蓝色加粗           │  │
│  │ 歌曲名       │  │  下一行 17pt 渐淡              │  │
│  │ 艺术家       │  │  ...                             │  │
│  │              │  │  点击任意行 → 跳转播放位置        │  │
│  │ [进度条]     │  │                                  │  │
│  │ ⤮ ◀ ⏸ ▶ 🔁│  │                                  │  │
│  │ ♥     🔊━━━ │  │                                  │  │
│  └──────────────┘  └──────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
```

- 直接监听 `AudioPlayerManager.$currentTime`（绕过 macOS `#if` 限制）
- 当前行自动滚动到视觉中心（`ScrollViewReader` + `anchor: .center`）
- 歌词行按距离当前行的远近渐淡显示
- 点击歌词行跳转到对应播放时间，暂停状态自动恢复播放

---

## 8. 持久化策略

### UserDefaults（本地，主要）

| Key | 类型 | 说明 |
|-----|------|------|
| `qingyin.lastPlayedSongID` | String | 上次播放歌曲的 UUID |
| `qingyin.lastPlayedTime` | Double | 播放位置（秒） |
| `qingyin.favoriteIDs` | Data (JSON [String]) | 喜欢的歌曲 UUID 列表 |
| `qingyin.playlists` | Data (JSON [Playlist]) | 播放列表完整数据 |
| `qingyin.isShuffleOn` | Bool | 随机播放开关 |
| `qingyin.repeatMode` | String | 循环模式 rawValue |
| `macLibraryColumnOrder` | [String] | 列顺序 |
| `macLibraryColumnWidths` | [String: CGFloat] | 列宽 |

### iCloud（备份，次要）

通过 `NSUbiquitousKeyValueStore` 同步：
- 播放列表 (JSON encoded)
- 喜欢列表 (UUID 字符串数组)
- 上次播放歌曲 ID + 时间

### 文件存储

| 路径 | 内容 |
|------|------|
| `Documents/Audio/` | 导入的音频文件副本 |
| `Documents/Audio/*.lrc` | 同名歌词文件（本地） |
| `Documents/Lyrics/` | 自动搜索下载的歌词缓存 (`{songID}.lrc`) |

---

## 9. 色彩系统

`QingYinColors` — 青花瓷设计色板

### 瓷白系列（背景/底色）

| 名称 | 色值 | 用途 |
|------|------|------|
| `porcelain` | `#F8F4EC` | 主背景 |
| `porcelainWarm` | `#F2ECE0` | 暖色背景（表头、侧栏、底部栏） |
| `porcelainDeep` | `#E8E0D0` | 深色背景（轨道、输入框边框） |

### 钴蓝系列（主色/交互）

| 名称 | 色值 | 用途 |
|------|------|------|
| `cobalt` | `#1A4B8C` | 主色调（按钮、选中、播放图标） |
| `cobaltLight` | `#2A6CB8` | 浅钴蓝 |
| `cobaltPale` | `#D6E4F2` | 淡蓝背景（封面占位） |
| `cobaltGhost` | `#EAF1F8` | 幽灵蓝（选中高亮背景） |

### 青瓷绿系列（辅助/次要）

| 名称 | 色值 | 用途 |
|------|------|------|
| `celadon` | `#6A9E96` | 青瓷绿（艺术家名、成功状态） |
| `celadonLight` | `#8FBDB4` | 浅青瓷 |
| `celadonPale` | `#D8EBE6` | 淡绿背景 |

### 墨色系列（文字）

| 名称 | 色值 | 用途 |
|------|------|------|
| `ink` | `#2A2A2A` | 主文字 |
| `inkLight` | `#5A5A5A` | 次要文字（未选中侧栏） |
| `inkMist` | `#8A8A8A` | 淡文字（时间、辅助信息） |

---

## 10. 构建与部署

### 项目生成

使用 XcodeGen，配置文件 `project.yml`：

```bash
# 安装 XcodeGen
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate
```

### 构建目标

| Target | 平台 | Bundle ID |
|--------|------|-----------|
| QingYin_macOS | macOS 13.0+ | com.qingyin.app.macos |
| QingYin_iOS | iOS 16.0+ (支持 Mac Catalyst) | com.qingyin.app.ios |

### 构建命令

```bash
# macOS
xcodebuild -project QingYin.xcodeproj -scheme QingYin_macOS build

# iOS（需要模拟器或真机）
xcodebuild -project QingYin.xcodeproj -scheme QingYin_iOS \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 依赖

仅系统框架，无第三方依赖：
- SwiftUI
- AVFoundation
- MediaPlayer (iOS)
- Combine
- CloudKit (NSUbiquitousKeyValueStore)
- UniformTypeIdentifiers

---

## 11. 已知限制与 TODO

### 当前限制

| 限制 | 说明 |
|------|------|
| 无网络流媒体 | 仅支持本地文件和系统音乐库 |
| iOS 端功能不完整 | MacLibraryView 的自定义表头/列宽仅 macOS |
| 无 AirPlay | 未实现投屏播放 |
| 无 MiniPlayer 窗口 | macOS 无独立小窗口模式 |
| 歌词来源有限 | LRCLIB 开源社区，冷门歌曲可能找不到 |

### 可考虑的 TODO

- [ ] 全局快捷键（媒体键播放/暂停/切歌）
- [ ] macOS 通知中心显示当前歌曲信息
- [ ] 音频可视化（波形/频谱）
- [ ] 播放统计（播放次数、最近播放）
- [ ] 专辑封面网格视图
- [ ] 睡眠定时器
- [ ] 歌曲标签编辑（ID3 tag 写入）
- [ ] 智能播放列表（按规则自动聚合）
- [ ] 导出播放列表为 M3U
- [ ] 手动搜索/编辑歌词
- [ ] 多歌词源备选（LRCLIB 失败时切换）
- [ ] 单元测试 / UI 测试
