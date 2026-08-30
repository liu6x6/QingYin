# 清音 (QingYin) — 开发日志

> macOS / iOS 青花瓷风格音乐播放器  
> 开发日期: 2026-08-25 ~ 2026-08-26

---

## 目录

1. [UI 优化](#1-ui-优化)
2. [播放控制 — 单击选中 / 双击播放](#2-播放控制--单击选中--双击播放)
3. [播放进度条 — 实时显示 + 拖拽控制](#3-播放进度条--实时显示--拖拽控制)
4. [随机播放 & 单曲循环](#4-随机播放--单曲循环)
5. [歌曲列表 — 表头与行对齐](#5-歌曲列表--表头与行对齐)
6. [窗口拉伸 — 列宽自适应](#6-窗口拉伸--列宽自适应)
7. [喜欢列表持久化](#7-喜欢列表持久化)
8. [拖拽导入音乐文件](#8-拖拽导入音乐文件)
9. [侧栏点击区域修复](#9-侧栏点击区域修复)
10. [启动恢复上次播放](#10-启动恢复上次播放)
11. [播放位置持续保存](#11-播放位置持续保存)
12. [2026-08-26：本地音乐体验完善](#12-2026-08-26本地音乐体验完善)
13. [表头列拖拽把手修复](#13-表头列拖拽把手修复)
14. [播放位置保存修复 — 防止 0s 覆盖](#14-播放位置保存修复--防止-0s-覆盖)
15. [全屏歌词面板](#15-全屏歌词面板)
16. [歌词自动搜索下载](#16-歌词自动搜索下载)
17. [歌词同步与点击跳转](#17-歌词同步与点击跳转)
18. [APP 图标 SVG 设计](#18-app-图标-svg-设计)
19. [设计令牌文档](#19-设计令牌文档)

---

## 1. UI 优化

### 问题
MacLibraryView 的表头（tableHeader）高度过高，显得突兀。

### 分析
- 原实现使用 `.padding(.vertical, 8)` 作为表头内边距
- macOS SwiftUI `List` 默认在顶部有额外空白区域

### 解决
- 表头改为 `.frame(height: 24)` 固定高度
- 添加底部分隔线 (cobalt 0.06 opacity)
- List 设置 `.environment(\.defaultMinListRowHeight, 1)` 减小默认行高
- List row 添加 `.listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))`

### 文件
- `Views/MacLibraryView.swift` — tableHeader, songList

---

## 2. 播放控制 — 单击选中 / 双击播放

### 问题
MacSongRow 单击就播放，用户期望单击选中、双击播放（与 iTunes/音乐 app 一致）。

### 分析
原实现 `.onTapGesture` 同时调用 `onSelect` 和 `onPlay`。

### 解决
SwiftUI 支持 `.onTapGesture(count:)` 区分单击/双击。**必须把 count:2 写在前面**，SwiftUI 才能先匹配双击。

```swift
.onTapGesture(count: 2) { onPlay() }
.onTapGesture { onSelect(flags) }
```

### 文件
- `Views/MacLibraryView.swift` — MacSongRow.body

---

## 3. 播放进度条 — 实时显示 + 拖拽控制

### 问题
1. 进度条不实时更新（拖拽后回弹到旧位置）
2. 进度条没有拖拽把手
3. 拖拽后播放位置不跳转

### 根因分析

#### 3a. 进度不更新
`MacPlayerBar` 通过 `@EnvironmentObject` 观察 `PlayerViewModel`，但 `currentTime`/`progress`/`duration` 是 `AudioPlayerManager` 上的 `@Published` 属性。SwiftUI 不会追踪引用类型内部嵌套的 `@Published`。

**解决**: 在 `PlayerViewModel` 中添加转发属性：
```swift
@Published var currentTime: TimeInterval = 0
@Published var progress: Double = 0
// ...
player.$currentTime.assign(to: &$currentTime)
player.$progress.assign(to: &$progress)
```

#### 3b. 拖拽回弹（三层竞态）

**原因 1 — isSeeking 锁释放太早**  
旧代码在 `player.seek` 的 completion handler 中立刻 `isSeeking = false`，但 AVPlayer 的 seek 完成回调和 periodic observer 几乎同时触发，加上 `Task { @MainActor }` 有一帧延迟。结果 observer 读到还没跳转完的旧时间。

**解决**: 改用时间戳锁。seek 后 1.5 秒内忽略 periodic observer 的更新：
```swift
private var lastSeekWallTime: Date = .distantPast

func seek(to progress: Double) {
    lastSeekWallTime = Date()
    player.seek(to: targetTime) { finished in
        // 不主动解锁，靠 1.5s 后自然解锁
    }
}

// periodic observer:
if Date().timeIntervalSince(self.lastSeekWallTime) < 1.5 { return }
```

**原因 2 — 手势被父视图吞掉**  
`DragGesture` 优先级低于 List 的滚动手势。

**解决**: 使用 `.highPriorityGesture` 替代 `.gesture`。

**原因 3 — ProgressSlider 视觉回弹**  
松手时 `isDragging = false`，`displayProgress` 切回外部 `progress`，但 Combine 管道还没把新值传回来。

**解决**: `lastSeekValue` 锁定机制：
```swift
@State private var lastSeekValue: Double = -1

var displayProgress: Double {
    if isDragging { return dragProgress }
    if lastSeekValue >= 0 { return lastSeekValue }  // 锁定
    return progress
}

.onChange(of: progress) { newValue in
    if abs(newValue - lastSeekValue) < 0.015 || newValue < 0.001 {
        lastSeekValue = -1  // progress 追上后解锁
    }
}

.onReceive(Timer.publish(every: 2, ...)) { _ in
    // 2 秒安全超时解锁
}
```

#### 3c. 其他修复
- **duration 可能为 0**: 异步加载未完成时 `self.duration` 为 0，guard 静默失败。修复为从 `currentItem.duration` 回退读取。
- **进度条无把手**: 新建 `ProgressSlider` 组件 — 轨道 3pt + 12px 圆形把手（悬停显示），触摸区扩展到 20pt。
- **periodic observer 频率**: 从 0.5s 提升到 0.25s，播放更平滑。

### 文件
- `Services/AudioPlayerManager.swift` — seek, timeObserver, isSeeking 机制
- `ViewModels/PlayerViewModel.swift` — 新增转发属性
- `Views/MacPlayerBar.swift` — ProgressSlider 组件
- `Views/NowPlayingView.swift` — 同步使用 ProgressSlider

---

## 4. 随机播放 & 单曲循环

### 问题
- 随机播放 `Int.random` 可能连续选同一首歌
- 单曲循环每次都 `loadAndPlay` 重建 AVPlayer，太重
- 用户按"下一首"在单曲循环下也循环当前歌
- `.off` 和 `.all` 共用同一个图标 `arrow.2.circlepath`，无法区分
- isShuffleOn / repeatMode 未通过 PlayerViewModel 转发

### 解决

#### 随机播放
改用 **Fisher-Yates 打乱顺序**：
```swift
private var shuffledOrder: [Int] = []
private var shuffledPointer: Int = 0

private func reshuffleQueue() {
    var indices = Array(0..<queue.count)
    indices.shuffle()
    // 确保当前歌排第一位
    if let pos = indices.firstIndex(of: currentIndex) {
        indices.swapAt(0, pos)
    }
    shuffledOrder = indices
    shuffledPointer = 0
}
```
- 按 `shuffledPointer` 顺序播放，播完重新打乱
- 上一首/下一首都支持回退/前进（指针移动）

#### 单曲循环
区分 `userInitiated: true/false`：
```swift
private func advanceToNext(userInitiated: Bool) {
    if repeatMode == .one && !userInitiated {
        // 自然结束 → seek(to: .zero) + play()，轻量
        player?.seek(to: .zero)
        player?.play()
        return
    }
    // 用户按下一首 → 跳到下一首
    ...
}
```

#### 顺序播放结束行为
- `.off`: 播到最后一首自动暂停
- `.all`: 循环回第一首

#### 上一首逻辑
播放 > 3秒 → 重头播放当前歌；< 3秒 → 跳到上一首（与 Apple Music 一致）

#### 图标三态
- `.off` → `arrow.triangle.2.circlepath`（灰色）
- `.all` → `repeat`（蓝色）
- `.one` → `repeat.1`（蓝色）

### 文件
- `Services/AudioPlayerManager.swift` — nextTrack, previousTrack, toggleShuffle, reshuffleQueue
- `ViewModels/PlayerViewModel.swift` — 转发 isShuffleOn, repeatMode
- `Views/MacPlayerBar.swift`, `Views/NowPlayingView.swift` — 图标和颜色

---

## 5. 歌曲列表 — 表头与行对齐

### 问题
表头的 "标题" 列比歌曲行中的 "标题" 偏右一格。

### 根因
- 表头: `.padding(.horizontal, 16)` = 16pt
- 歌曲行: `listRowInsets(leading: 16)` + `.padding(.horizontal, 8)` = 24pt

差了 8pt。

### 解决
将 List 替换为 `ScrollView + LazyVStack`，彻底消除 macOS List 的不可控内置 insets。表头和行共享 `.padding(.horizontal, 16)`。

### 文件
- `Views/MacLibraryView.swift` — songList

---

## 6. 窗口拉伸 — 列宽自适应

### 问题
固定列宽（index 40 + title 280 + artist 140 + album 180 + duration 70 + favorite 50 = 760pt），窗口拉宽后剩余空间未被填充。

### 解决
1. `Column` 枚举新增 `isFlexible` 属性，`title` 为弹性列
2. 新增 `effectiveColumnWidths(totalWidth:)` — 固定列宽不变，剩余空间全部分配给弹性列
3. 用 `GeometryReader` 包裹表头+列表，共享同一份宽度计算
4. 行加 `frame(maxWidth: .infinity, alignment: .leading)` 使背景铺满

```swift
private func effectiveColumnWidths(totalWidth: CGFloat) -> [Column: CGFloat] {
    let padding: CGFloat = 32  // 左右各 16pt
    let available = totalWidth - padding
    let fixedTotal = columnOrder.reduce(0.0) { sum, col in
        sum + (col.isFlexible ? 0 : (columnWidths[col] ?? 80))
    }
    let remaining = max(80, available - fixedTotal)
    var result = columnWidths
    if let flexCol = columnOrder.first(where: { $0.isFlexible }) {
        result[flexCol] = remaining
    }
    return result
}
```

### 文件
- `Views/MacLibraryView.swift` — Column, effectiveColumnWidths, body, tableHeader, songList

---

## 7. 喜欢列表持久化

### 问题
关闭 APP 再打开，喜欢的歌曲全部丢失。

### 根因分析

**根因 1 — Song ID 不稳定**  
`LocalFileService.createSong(from:)` 每次扫描用 `UUID()` 生成随机 ID。重启后同一文件的 ID 变了，存的 favorite UUID 自然对不上。

**根因 2 — 未调用恢复**  
`restoreFavorites()` 从未在 `init()` 中调用。

### 解决

#### 稳定 ID
新增 `Song.stableID(from:)` — 基于 FNV-1a 哈希的确定性 UUID：
```swift
static func stableID(from string: String) -> UUID {
    let data = Array(string.utf8)
    var bytes = Array(repeating: UInt8(0), count: 16)
    for round in 0..<4 {
        var h: UInt64 = 0xcbf29ce484222325 ^ UInt64(round)
        for byte in data { h ^= UInt64(byte); h = h &* 0x100000001b3 }
        // fill 4 bytes per round
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x50  // version 5
    bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant 1
    return UUID(uuid: (...))
}
```

各 Service 使用方式：
| 来源 | ID 生成方式 |
|------|-----------|
| `LocalFileService` | `stableID(forFilePath: url.path)` |
| `MusicLibraryService` (iOS) | `stableID(from: "media:\(persistentID)")` |
| `AppleMusicMacService` | `stableID(forFilePath: url.path)` |
| Sample songs | `stableID(from: "sample:夜曲:周杰伦")` |

Playlist ID 也稳定: `Song.stableID(from: "playlist:\(name)")`

#### 持久化链路
- `init()` 调用 `restoreFavorites()` + `restoreLocalPlaylists()`
- `$favoriteIDs` 变化自动触发 `saveFavorites()`
- UserDefaults 本地持久化（优先）+ iCloud（备份）
- 双向去重: 按 ID + 按文件路径

### 文件
- `Models/Song.swift` — stableID
- `Models/Playlist.swift` — 稳定 ID
- `Services/LocalFileService.swift` — createSong 用 stableID
- `Services/MusicLibraryService.swift` — iOS 媒体库
- `Services/AppleMusicMacService.swift` — macOS 扫描
- `ViewModels/LibraryViewModel.swift` — 持久化

---

## 8. 拖拽导入音乐文件

### 问题
用户希望从 Finder 拖拽音频文件到 APP 窗口，自动导入。单文件自动播放，多文件只添加。已有歌曲不重复。

### 开发过程（迭代 5 次）

#### 第 1 版 — 基础 onDrop
```swift
.onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
    Task {
        for provider in providers {
            let url = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL
        }
    }
}
```
**失败**: async/await 版本的 loadItem 在 macOS `.onDrop` 中静默失败。

#### 第 2 版 — DispatchGroup + 回调
改用 `provider.loadItem(forTypeIdentifier:options:completion:)` 回调版本。
**失败**: `loadItem` 返回 `__NSSwiftData` (Data)，不是 URL。

#### 第 3 版 — Data 解码为字符串
尝试 UTF-8/UTF-16/ASCII 解码 Data。
**失败**: Data 解码后是 `file:///.file/id=6571367.335700` — macOS 沙箱 file reference URL，不含真实路径和扩展名。

#### 第 4 版 — loadFileRepresentation
改用 `provider.loadFileRepresentation` 复制文件到沙箱临时目录。
**失败**: 文件被复制但名字变成 `"file URL"`，扩展名丢失。

#### 第 5 版（最终方案） — loadItem + resolvingSymlinksInPath
```swift
provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
    // 1. Data 解码 → "file:///.file/id=xxx" URL 字符串
    let str = String(data: data, encoding: .utf8)
    let url = URL(string: str)
    
    // 2. resolvingSymlinksInPath() → 真实路径
    let resolved = try url.resolvingSymlinksInPath()
    // → /Users/xxx/Music/Acreix - Visions.mp3
    
    // 3. 如果仍无扩展名，用 UTType contentType 推断
    let resourceValues = try resolved.resourceValues(forKeys: [.contentTypeKey])
    let ext = resourceValues.contentType?.preferredFilenameExtension
}
```

### 去重
- `LocalFileService.importAudioFile`: 同名文件已存在直接返回
- `LibraryViewModel.importAudioFiles`: 返回数组过滤掉已存在的 ID
- `allSongs`: 按 ID + 路径双重去重

### 文件
- `Views/MacLibraryView.swift` — onDrop + overlay
- `Services/LocalFileService.swift` — importAudioFile 去重
- `ViewModels/LibraryViewModel.swift` — importAudioFiles, allSongs 去重

---

## 9. 侧栏点击区域修复

### 问题
MacSidebarItem 只有点击文字区域才有反应，点击右侧空白无响应。

### 根因
SwiftUI `Button` 内的 `Spacer()` 创建空白区域默认不可点击。

### 解决
在 `.background` 前添加 `.contentShape(Rectangle())`：
```swift
HStack { ... Spacer() }
.contentShape(Rectangle())  // ← 关键
.background(...)
```

### 文件
- `Views/ContentView.swift` — MacSidebarItem

---

## 10. 启动恢复上次播放

### 问题
打开 APP 时希望自动选择上次播放的歌曲（不自动播放）。

### 解决
- **保存**: `$currentSong` 变化时保存 song ID 到 UserDefaults
- **恢复**: `restoreLastPlayed(from:)` 从 allSongs 中查找歌曲，设置 `currentSong`/`queue`/`currentIndex`，加载 AVPlayer 并 seek 到上次位置
- **触发**: `QingYinApp` 用 Timer 轮询等 allSongs 非空后执行一次
- **防止弹窗**: `isRestoring` 标志让 PlayerViewModel 跳过 `isNowPlayingPresented = true`

### 文件
- `Services/AudioPlayerManager.swift` — restoreLastPlayed, isRestoring
- `ViewModels/PlayerViewModel.swift` — isRestoring 检查
- `QingYinApp.swift` — Timer 触发恢复

---

## 11. 播放位置持续保存

### 问题
仅保存了歌曲 ID，播放时间没有持续保存。下次打开无法从上次位置继续。

### 解决 — 三个保存时机

| 时机 | 实现 |
|------|------|
| 暂停/停止 | `$playbackState` 监听 → saveCurrentTime() |
| 播放中 | `$currentTime` + `.throttle(for: .seconds(5))` 每 5 秒保存 |
| APP 关闭 | macOS: `NSApplication.willTerminateNotification` / iOS: `willTerminateNotification` + `willDeactivateNotification` |

```swift
private func saveCurrentTime() {
    UserDefaults.standard.set(currentTime, forKey: PersistenceKey.lastPlayedTime.rawValue)
}
```

### 文件
- `Services/AudioPlayerManager.swift` — saveCurrentTime, init 监听

---

## 12. 2026-08-26：本地音乐体验完善

### 均衡器与本地播放
- 新增十段均衡器模型、预设、预放大、持久化与青花瓷风格界面。
- 本地播放迁移至 `AVAudioEngine + AVAudioPlayerNode + AVAudioUnitEQ`，支持实时调音。
- iOS、iPadOS 与 macOS 均可从设置进入；Mac 另提供侧边栏和播放条快捷入口。

### 专辑、艺术家与播放列表
- 专辑和艺术家均改为自适应主从布局：Mac/iPad 同屏浏览，iPhone 自动折叠为导航层级。
- 专辑/艺术家详情支持播放全部、随机播放、曲目选择和播放控制。
- “我的列表”由 mock 网格升级为真实播放列表管理：创建、重命名、删除、添加/移除歌曲、播放和随机播放均持久化并同步。
- 歌曲支持通过 macOS 右键菜单或 iOS 长按菜单添加到指定播放列表；Mac 多选歌曲仍支持批量添加。

### Apple Music 本地文件
- macOS 扫描结果自动创建或更新“Apple Music”播放列表。
- 已扫描歌曲索引写入本地缓存，启动时恢复，不再每次扫描磁盘。
- 将 macOS 的本地文件访问与 iOS 的 MediaPlayer 权限分离，避免本地播放触发 Apple Music 授权。

### macOS 交互稳定性
- 修复播放列表二级菜单在播放期间闪烁的问题。
- 播放进度仅由底部播放条直接观察；资料库不再接收每 0.25 秒的进度更新。
- 保留歌曲行的 EQ 播放动画，同时让右键菜单不受其影响。

### 文件
- `Models/EqualizerSettings.swift`, `Services/AudioPlayerManager.swift`
- `Views/EqualizerView.swift`, `Views/AlbumListView.swift`, `Views/PlaylistView.swift`
- `Services/AppleMusicMacService.swift`, `Services/MusicLibraryService.swift`
- `ViewModels/LibraryViewModel.swift`, `ViewModels/PlayerViewModel.swift`
- `Views/MacLibraryView.swift`, `Views/MacPlayerBar.swift`

---

## 13. 表头列拖拽把手修复

### 问题
MacLibraryView 的表头中，“标题”和“艺术家”列之间的分隔线无法拖拽调整宽度，但其他列可以。

### 根因分析

**问题 1：标题列拖拽把手被隐藏**
```swift
// 错误代码：!column.isFlexible 条件排除了弹性列
if column.isResizable && !column.isFlexible {
    // 拖拽把手代码
}
```
由于“标题”列被设为弹性列（`isFlexible = true`），条件判断为 false，不渲染把手。

**问题 2：分隔线视觉 bug**
```swift
// 错误代码：两个 .frame 修饰符，后者覆盖前者
Rectangle()
    .frame(width: 1)   // 1pt 宽
    .frame(width: 8)   // 被覆盖为 8pt 宽矩形
```

**问题 3：手势冲突**
`.gesture` 被 `.onTapGesture`（排序点击）和外层 `.gesture`（列拖拽排序）抢占，导致拖拽不响应。

### 解决

**修复 1：移除弹性列排除条件**
```swift
if column.isResizable {  // 所有可调整列都有把手
    resizeHandle(for: column)
}
```

**修复 2：ZStack 分离可见层和触摸层**
```swift
ZStack {
    Rectangle()
        .fill(QingYinColors.cobalt.opacity(0.15))
        .frame(width: 1)  // 1pt 可见分隔线
    
    Rectangle()
        .fill(Color.clear)
        .frame(width: 10)  // 10pt 透明触摸区，更容易点击
}
```

**修复 3：highPriorityGesture 提高优先级**
```swift
.highPriorityGesture(
    DragGesture(minimumDistance: 1)
        .onChanged { value in ... }
)
```

**弹性列宽度保持**：`effectiveColumnWidths` 中弹性列取 `max(用户拖拽宽度, 剩余空间)`，用户拉宽后不会被强制缩回。

### 文件
- `Views/MacLibraryView.swift` — headerCell, resizeHandle, effectiveColumnWidths

---

## 14. 播放位置保存修复 — 防止 0s 覆盖

### 问题
关闭 APP 后重新打开，播放位置从 0 开始，而不是上次播放的位置（如 22s）。

日志显示：
```
🔄 restoreLastPlayed: 那一年, savedTime=0s
💾 saveCurrentTime: SKIPPED (保护期, time=0s)
```

### 根因分析

**保存链路**：
1. 播放中 → `updatePlaybackProgress()` 每 5 秒保存 ✅ 保存了 22s
2. 歌曲播完 → `advanceToNext()` → `pause()` → `load()` 把 `currentTime` 重置为 0
3. 关闭 APP → `willResignActiveNotification` 触发 → `saveCurrentTime()` 用 **0s 覆盖了 22s** ❌
4. 重新打开 → 读到 0s

### 解决 — 核心保护规则

**永远不用 0s 覆盖已有的有效位置**：

```swift
private func saveCurrentTime() {
    let time = currentTime
    
    // 恢复保护期内，不保存 0s
    if Date() < saveProtectionUntil && time < 1 {
        print("💾 saveCurrentTime: SKIPPED (保护期)")
        return
    }
    
    // 核心保护：永远不要用 0s 覆盖已有的有效位置
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
```

**恢复保护期**：`restoreLastPlayed` 设置 3 秒保护期，防止恢复后立即保存 0s。

### 文件
- `Services/AudioPlayerManager.swift` — saveCurrentTime, restoreLastPlayed

---

## 15. 全屏歌词面板

### 问题
1. 歌词视图只从右侧滑入，宽度 720pt，左侧留 120pt 空白，不美观
2. 歌词不同步 — macOS 上 `PlayerViewModel.currentTime` 被 `#if !os(macOS)` 跳过，收不到时间更新
3. 点击歌词跳转已实现但需验证

### 解决

**问题 1：全屏覆盖**

重写 `LyricsPanelView`，改为全屏覆盖整个 APP 窗口：

```
┌─ LyricsPanelView（全屏覆盖）───────────────────────────┐
│                                                    [↓] │
│                                                        │
│  ┌─────────────┐   ┌──────────────────────────────┐   │
│  │             │   │                              │   │
│  │  封面 240px  │   │   歌词文本                    │   │
│  │             │   │   ▶ 当前行（22pt 蓝色加粗）    │   │
│  └─────────────┘   │   下一行（17pt）              │   │
│                     │   再下一行...                 │   │
│  歌曲名 / 艺术家     │                              │   │
│  [进度条]           │   点击任意行 → 跳转播放位置    │   │
│  ⤮ ◀ ⏸ ▶ 🔁      │                              │   │
│  ♥          🔊━━━  │                              │   │
└────────────────────────────────────────────────────────┘
```

**问题 2：歌词时间同步**

**根因**：`PlayerViewModel.currentTime` 在 macOS 上被 `#if !os(macOS)` 跳过，不会更新。

**修复**：`LyricsPanelView` 直接监听 `AudioPlayerManager.$currentTime`：
```swift
private let audioPlayer = AudioPlayerManager.shared

.onReceive(audioPlayer.$currentTime) { time in
    currentTime = time
    updateCurrentLine(time: time)
}
```

**问题 3：点击歌词跳转**

已实现，点击歌词行会：
1. **跳转到对应时间** — `audioPlayer.seek(to: line.time / duration)`
2. **自动恢复播放** — 如果处于暂停状态，点击后自动 resume

```swift
.onTapGesture {
    guard audioPlayer.duration > 0 else { return }
    let progress = line.time / audioPlayer.duration
    audioPlayer.seek(to: progress)
    if audioPlayer.playbackState != .playing {
        audioPlayer.resume()
    }
}
```

### 歌词视觉样式

| 状态 | 字号 | 字重 | 颜色 |
|------|------|------|------|
| 当前行 | 22pt | `.bold` | cobalt（蓝色） |
| 已播过 | 17pt | `.medium` | ink 35% opacity |
| 临近行 | 17pt | `.medium` | 按距离递减（50% → 20%） |
| 远处行 | 17pt | `.medium` | inkMist 20% opacity |

### 文件
- `Views/LyricsPanelView.swift` — 重写为全屏面板
- `Views/ContentView.swift` — overlay 层全屏覆盖

---

## 16. 歌词自动搜索下载

### 问题
用户希望 APP 自动搜索并下载歌词，缓存到本地，避免每次重复下载。

### 解决

**数据流**：
```
歌曲切换
  ↓
PlayerViewModel.fetchLyrics()
  ↓
┌─ song.lyrics 有值？ → 直接使用（本地 .lrc 文件）
└─ 没有 → LyricsService.getLyrics()
          ↓
         ① 内存缓存 → 命中则返回
         ② 磁盘缓存 (Documents/Lyrics/{songID}.lrc) → 命中则返回
         ③ LRCLIB API 搜索
            → 精确匹配 (title + artist)
            → 模糊搜索 (title)
            → 模糊搜索 (title + artist)
            → 命中则缓存到内存 + 磁盘
            → 全部未找到 → 缓存空结果（避免重复搜索）
  ↓
@Published currentLyrics 更新
  ↓
LyricsPanelView / LyricsView 自动刷新
```

**API 来源**：
- **地址**: `https://lrclib.net/api`
- **类型**: 开源免费歌词 API
- **特点**: 无需 API Key，直接返回 LRC 格式歌词，支持中文

**搜索策略（三级降级）**：
```swift
// 1. 精确匹配（标题 + 艺术家）
GET /api/get?artist_name=周杰伦&track_name=晴天

// 2. 模糊搜索（仅标题）
GET /api/search?q=晴天

// 3. 模糊搜索（标题 + 艺术家）
GET /api/search?q=晴天 周杰伦
```

**缓存机制（三级）**：
```swift
1. 内存缓存  → 最快，APP 运行期间
2. 磁盘缓存  → Documents/Lyrics/{songID}.lrc
3. 网络请求  → LRCLIB API
```

### 文件
- `Services/LyricsService.swift` — 歌词搜索与缓存服务（新建）
- `ViewModels/PlayerViewModel.swift` — 新增 `currentLyrics`, `isLyricsLoading`, `fetchLyrics()`
- `Views/LyricsPanelView.swift` — 读取 `currentLyrics`，显示加载状态
- `Views/LyricsView.swift` — 同步更新，读取 `currentLyrics`

---

## 17. 歌词同步与点击跳转

### 问题
1. 歌词没有随时间变化的效果（不同步）
2. 用户希望通过滚动/点击歌词跳转到对应播放时间

### 解决

**歌词同步**：

通过 `onReceive(audioPlayer.$currentTime)` 实时监听播放时间，更新 `currentLineIndex`：

```swift
.onReceive(audioPlayer.$currentTime) { time in
    currentTime = time
    updateCurrentLine(time: time)
}

private func updateCurrentLine(time: TimeInterval) {
    let newIndex = parsedLyrics.currentIndex(at: time)
    if newIndex != currentLineIndex {
        currentLineIndex = newIndex
    }
}
```

**自动滚动**：

使用 `ScrollViewReader` + `onChange`，当前行变化时自动滚动到中心：

```swift
.onChange(of: currentLineIndex) { newIndex in
    guard let newIndex = newIndex else { return }
    withAnimation(.easeInOut(duration: 0.6)) {
        proxy.scrollTo(newIndex, anchor: .center)
    }
}
```

**点击跳转**：

每行歌词添加 `onTapGesture`，点击后跳转并自动播放：

```swift
.onTapGesture {
    guard audioPlayer.duration > 0 else { return }
    let progress = line.time / audioPlayer.duration
    audioPlayer.seek(to: progress)
    if audioPlayer.playbackState != .playing {
        audioPlayer.resume()
    }
}
```

### 文件
- `Views/LyricsPanelView.swift` — updateCurrentLine, scrollTo, onTapGesture

---

## 18. APP 图标 SVG 设计

### 任务
生成 6 张 SVG 图标，融合音乐和青花瓷元素，使用原型中的色调。

### 生成内容

| 文件名 | 设计风格 | 说明 |
|--------|---------|------|
| `icon-1-porcelain-disc.svg` | 青花瓷唱片 | 钴蓝色唱片外环 + 中心青花莲花图案（8瓣 + 8瓣错位） |
| `icon-2-cloud-note.svg` | 祥云音符 | 瓷白背景 + 四角祥云纹 + 中央大音符 |
| `icon-3-brush-circle.svg` | 水墨圆圈 | 毛笔画圆（笔触粗细变化）+ 圆内钴蓝十六分音符 + 红色印章 |
| `icon-4-round-window.svg` | 青花圆窗 | 深钴蓝背景 + 白色圆窗（仿古建筑）+ 窗内青花莲花 |
| `icon-5-yin-yang-music.svg` | 音乐阴阳 | 阴阳图案 + 上下音符 + 象征音乐的动静对立统一 |
| `icon-6-vase-music.svg` | 青花花瓶 | 白色花瓶 + 瓶内梅花枝青花 + 音符从瓶口飘出 |

### 文件
- `icon-1-porcelain-disc.svg` ~ `icon-6-vase-music.svg` — 6 张 SVG 图标

---

## 19. 设计令牌文档

### 任务
创建设计令牌文档，记录颜色、字号、间距、圆角等视觉规范，方便 AI 持续开发时参考。

### 内容

生成 `design-tokens.md`，包含 11 个章节：

| 章节 | 内容 |
|------|------|
| **1. 色彩系统** | 13 个颜色 token + 5 种语义色 + 不透明度规范 + 使用频率统计 |
| **2. 字体系统** | 16 级字号层级（8pt~20pt）+ 场景速查表 |
| **3. 间距系统** | 内边距 6 档 + 元素间距 10 档 + 尺寸规范表 |
| **4. 圆角系统** | 8 档（1pt~50%） |
| **5. 描边/边框** | 7 种描边样式 |
| **6. 阴影** | 2 种标准阴影参数 |
| **7. 布局规范** | macOS 主布局 ASCII 图 + 弹性列规则 + 背景分层 |
| **8. 动效规范** | EQ 动画、hover、拖拽动效参数 |
| **9. 交互规范** | 点击行为、播放模式、上一首/下一首逻辑表 |
| **10. Swift 代码模式** | 6 种标准组件的 Swift 代码模板 |
| **11. 图标尺寸** | 各场景图标字号和颜色 |

### 文件
- `design-tokens.md` — 完整设计令牌文档（548 行）
