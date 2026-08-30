# 清音 (QingYin) — 设计令牌 (Design Tokens)

> 本文件是 AI 开发时的**唯一视觉真相来源**。  
> 所有 UI 组件的颜色、字号、间距、圆角等必须参考此文件。

---

## 1. 色彩系统

### 1.1 瓷白系 (背景/表面)

| Token | 色值 | RGB | 用途 |
|-------|------|-----|------|
| `porcelain` | `#F8F4EC` | (248,244,236) | **主背景**，所有页面底色 |
| `porcelainWarm` | `#F2ECE0` | (242,236,224) | **暖色表面**，表头、侧栏、底部栏、工具栏 |
| `porcelainDeep` | `#E8E0D0` | (232,224,208) | **深色表面**，进度条轨道、输入框底色 |

### 1.2 钴蓝系 (主色/交互)

| Token | 色值 | RGB | 用途 |
|-------|------|-----|------|
| `cobalt` | `#1A4B8C` | (26,75,140) | **主色调**，按钮、选中态、播放图标、链接、表头排序箭头 |
| `cobaltLight` | `#2A6CB8` | (42,108,184) | **浅钴蓝**，次要强调 |
| `cobaltPale` | `#D6E4F2` | (214,228,242) | **淡蓝背景**，封面占位符、卡片底色 |
| `cobaltGhost` | `#EAF1F8` | (234,241,248) | **幽灵蓝**，选中行高亮背景、Hover 态 |

### 1.3 青瓷绿系 (辅助/成功)

| Token | 色值 | RGB | 用途 |
|-------|------|-----|------|
| `celadon` | `#6A9E96` | (106,158,150) | **青瓷绿**，艺术家名、成功状态、"查看全部"链接 |
| `celadonLight` | `#8FBDB4` | (143,189,180) | **浅青**，装饰元素 |
| `celadonPale` | `#D8EBE6` | (216,235,230) | **淡绿背景**，艺术家头像占位 |

### 1.4 墨色系 (文字)

| Token | 色值 | RGB | 用途 |
|-------|------|-----|------|
| `ink` | `#2A2A2A` | (42,42,42) | **主文字**，标题、歌曲名、重要信息 |
| `inkLight` | `#5A5A5A` | (90,90,90) | **次要文字**，未选中侧栏项 |
| `inkMist` | `#8A8A8A` | (138,138,138) | **淡文字**，时间、辅助信息、占位文本 |

### 1.5 语义色 (不定义新颜色，用现有 token 组合)

| 语义 | 实际 Token |
|------|-----------|
| 主按钮/CTA | `cobalt` |
| 已选中/激活 | `cobalt` 文字 + `cobaltGhost` 背景 |
| 成功/完成 | `celadon` |
| 警告/危险 | 系统 `.destructive`（红色） |
| 分隔线/规则线 | `cobalt` at `opacity(0.06)` |
| 描边/边框 | `cobalt` at `opacity(0.10~0.12)` |
| 强描边 | `cobalt` at `opacity(0.18~0.20)` |

### 1.6 不透明度规范

| 用途 | Opacity |
|------|---------|
| 分隔线（极淡） | `0.06` |
| 描边/边框（淡） | `0.08 ~ 0.12` |
| 描边/边框（中） | `0.15 ~ 0.20` |
| 图标/装饰（弱） | `0.30 ~ 0.40` |
| 不可用/占位 | `0.45 ~ 0.55` |
| 正常不透明 | `1.0` |

### 1.7 色彩使用频率 (从高到低)

```
inkMist    ████████████████████  78次 — 辅助文字、时间、占位
cobalt     ████████████████████  78次 — 主色、按钮、选中态
porcelain  ███████████          44次 — 主背景
ink        █████████            38次 — 主文字
celadon    ████                 15次 — 辅助色
cobaltGhost ███                 12次 — 高亮背景
cobaltPale  ███                 11次 — 封面占位
porcelainDeep █                 6次 — 轨道/输入框
porcelainWarm █                 5次 — 表面
celadonPale  █                  5次 — 艺术家头像
inkLight     █                  4次 — 次要文字
```

---

## 2. 字体系统

### 2.1 字体族

- **系统字体**：`.system` (San Francisco on macOS/iOS)
- **等宽数字**：`.monospacedDigit()` — 用于时间显示，防止数字跳动

### 2.2 字号层级

| 层级 | 字号 | 字重 | 用途 |
|------|------|------|------|
| **页面标题** | 18pt | `.semibold` | 页面名称（"歌曲"、"专辑"、"设置"） |
| **区域标题** | 20pt | `.semibold` | NowPlaying 歌曲名 |
| **次级标题** | 16pt | `.semibold` | Sheet 标题 |
| **播放控制图标** | 16pt | — | 播放/暂停/随机/循环按钮 |
| **正文/歌曲名** | 15pt | `.medium` | 歌曲列表标题 |
| **歌曲名（当前播放）** | 15pt | `.semibold` | 正在播放的歌曲 |
| **常规文字** | 14pt | `.regular` | 侧栏项目、描述文本 |
| **常规文字（中等）** | 14pt | `.medium` | 强调的常规文字 |
| **行内正文** | 13pt | `.regular` | 歌曲行标题、侧栏项 |
| **行内正文（中等）** | 13pt | `.medium` | 选中的侧栏项、当前歌曲行 |
| **辅助文字** | 12pt | `.regular` | 艺术家名、时长、歌曲信息、筛选标签 |
| **辅助文字（中等）** | 12pt | `.medium` | NowPlaying 标题、底部栏歌曲名 |
| **小文字** | 11pt | `.medium` | 表头列名、筛选 chip、排序箭头、底部栏歌曲名 |
| **迷你文字** | 10pt | — | 时间标签、底部操作按钮文字、歌曲总时长 |
| **微型文字** | 9pt | — | 进度条两侧时间（已播放/总时长） |
| **图标文字** | 8pt | — | 排序方向箭头 ▲▼ |

### 2.3 字体使用场景速查

```
页面标题 (表头)        → 11pt .medium  inkMist
工具栏标题            → 18pt .semibold  ink
歌曲列表 - 标题       → 15pt .regular   ink (当前播放: cobalt)
歌曲列表 - 艺术家/专辑 → 12pt .regular   inkMist
歌曲列表 - 时长       → 12pt .regular   inkMist
歌曲列表 - 序号       → 12pt .regular   inkMist (当前: cobalt .medium)
底部栏 - 歌曲名       → 12pt .medium   ink
底部栏 - 艺术家       → 11pt .regular   inkMist
底部栏 - 时间         → 9pt  .regular   inkMist .monospacedDigit()
播放按钮 (大)         → 22pt            cobalt
播放按钮 (中)         → 16pt            cobalt
控制按钮 (前后)       → 13pt            ink
侧栏 - 选中           → 13pt .medium   cobalt + cobaltGhost背景
侧栏 - 未选中         → 13pt .regular   inkLight
筛选 Chip - 选中      → 12pt .medium   white + cobalt背景
筛选 Chip - 未选中    → 12pt .medium   inkLight + cobalt描边
NowPlaying 标题       → 20pt .semibold  ink
NowPlaying 艺术家     → 14pt .regular   celadon
```

---

## 3. 间距系统

### 3.1 内边距 (Padding)

| 值 | 用途 |
|----|------|
| `16pt` | **页面水平边距**（内容距左右边缘） |
| `12pt` | **区域垂直边距**（表头、工具栏、底部栏的上下 padding） |
| `10pt` | **底部播放条**垂直内边距 |
| `8pt` | **区域间距**、按钮内垂直间距 |
| `6pt` | **紧凑垂直间距**（行内上下 padding） |
| `5pt` | **歌曲行**垂直内边距 |
| `4pt` | **表头**紧凑垂直内边距 |

### 3.2 元素间距 (Spacing in HStack/VStack)

| 值 | 用途 |
|----|------|
| `0` | 紧凑排列（表头列、歌曲行列） |
| `2` | 极紧凑（EQ 条之间、排序箭头与文字） |
| `4` | 小间距（控制按钮内图标与文字） |
| `6` | 文字与图标间距 |
| `8` | 常规间距（时间-进度条、音量图标-滑块） |
| `10` | 封面-文字间距、搜索图标-输入框 |
| `12` | **最常用**（歌曲行内各元素、列表项间距） |
| `16` | 大间距（播放控制按钮之间） |
| `32` | 超大间距（NowPlaying 控制按钮组） |

### 3.3 尺寸规范

| 元素 | 尺寸 |
|------|------|
| 歌曲封面（列表行） | 34×34pt |
| 歌曲封面（底部栏） | 40×40pt |
| 歌曲封面（iOS 列表） | 44×44pt |
| 播放按钮（NowPlaying） | 56×56pt 描边圆 |
| 进度条轨道高度 | 3pt |
| 进度条把手 | 12×12pt 圆形 |
| 进度条触摸区 | 20pt 高 |
| 音量条宽度 | 60pt |
| 分隔线高度 | 1pt |
| 表头高度 | 24pt |
| 侧栏宽度 | 180pt |
| 搜索框 | 200pt 宽 |
| 底部栏按钮区高度 | 约 60pt（含 padding） |

---

## 4. 圆角系统

| 值 | 用途 |
|----|------|
| `1pt` | 分隔线、进度条轨道 |
| `4pt` | 小元素（封面、小图标背景） |
| `6pt` | **标准**（歌曲行背景、按钮、输入框） |
| `8pt` | 中等容器（搜索框、迷你播放器卡片、拖拽提示框） |
| `12pt` | 大容器（拖拽目标提示、Sheet 面板） |
| `16pt` | 胶囊形（Chip 标签、筛选按钮） |
| `28pt` | 头像圆形（艺术家头像） |
| `50%` | 完美圆形（播放按钮描边圆、唱片封面） |

---

## 5. 描边/边框

| 元素 | 描边颜色 | 宽度 | 样式 |
|------|---------|------|------|
| 分隔线 | `cobalt.opacity(0.06)` | 1pt | 实线 |
| 输入框/搜索框 | `cobalt.opacity(0.12)` | 1pt | 实线 |
| 歌曲行选中描边 | `cobalt.opacity(0.10)` | 1pt | 实线 |
| 封面占位描边 | `cobalt.opacity(0.10~0.12)` | 1pt | 实线 |
| 播放按钮描边 | `cobalt` | 1.5pt | 实线 |
| 拖拽目标虚线 | `cobalt` | 2pt | `[8,4]` 虚线 |
| 强分隔线 | `cobalt.opacity(0.18)` | 1pt | 实线 |

---

## 6. 阴影

| 元素 | 参数 |
|------|------|
| 进度条把手 | `color: cobalt.opacity(0.3), radius: 2, x: 0, y: 1` |
| 青花瓷唱片封面 | `color: cobalt.opacity(0.08), radius: 20, x: 0, y: 10` |

---

## 7. 布局规范

### 7.1 macOS 主布局

```
┌──────────────────────────────────────────────┐
│  侧栏 (180pt)  │  内容区 (flex)              │
│  porcelainWarm  │  porcelain                 │
│                 │                            │
│  ┌─ 工具栏 ────────────────────────────┐     │
│  │ 标题 18pt .semibold                 │     │
│  │ 搜索框 200pt                        │     │
│  └─────────────────────────────────────┘     │
│  ┌─ 表头 (24pt) ──────────────────────┐      │
│  │ #  标题(flex)  艺术家  专辑  时长  ♥│      │
│  └─────────────────────────────────────┘     │
│  ┌─ 歌曲列表 (ScrollView) ───────────┐      │
│  │ 每行: 封面34 + 标题 + 信息 + 时长  │      │
│  └─────────────────────────────────────┘     │
│  ┌─ 底部栏 ───────────────────────────┐      │
│  │ 封面40 │ 控制 │ 进度条 │ 音量      │      │
│  └─────────────────────────────────────┘     │
└──────────────────────────────────────────────┘
```

### 7.2 弹性列

- 标题列 (`title`) 为弹性列，吸收窗口剩余宽度
- 其他列固定宽度，可用户拖拽调整
- 最小列宽: 80pt
- 列宽保存到 UserDefaults

### 7.3 背景分层

```
底层: porcelain (#F8F4EC) — 主背景
表面: porcelainWarm (#F2ECE0) — 表头/侧栏/底部栏
深面: porcelainDeep (#E8E0D0) — 输入框/轨道
高亮: cobaltGhost (#EAF1F8) — 选中行/hover
```

---

## 8. 动效规范

| 元素 | 动效 |
|------|------|
| EQ 均衡器条 | `.easeInOut(0.5s).repeatForever(autoreverses: true)`，高度 10~16pt，每根延迟 0.15s |
| Hover 背景 | 直接切换，无过渡（macOS 原生行为） |
| 进度条把手 | 无过渡，悬停即显示 |
| 拖拽把手 | 跟随手指实时更新位置 |
| 拖拽目标 | 蓝色虚线 + 毛玻璃背景淡入 |

---

## 9. 交互规范

### 9.1 点击行为

| 操作 | 行为 |
|------|------|
| 单击歌曲行 | 选中（高亮），支持 Command/Shift 多选 |
| 双击歌曲行 | 播放该歌曲 |
| 点击表头列名 | 按该列排序（升序/降序切换） |
| 点击侧栏项 | 切换内容区（整行可点击，含空白区域） |
| 点击筛选 Chip | 切换筛选条件 |
| 拖拽表头分隔线 | 调整列宽 |
| 拖拽表头列名 (>20pt) | 拖拽列排序 |
| 拖拽进度条 | 实时预览 + 松手跳转 |
| 拖拽音量条 | 实时调整音量 |
| 拖拽文件到窗口 | 导入音频文件 |

### 9.2 播放模式

| 模式 | 图标 | 颜色 | 行为 |
|------|------|------|------|
| 关闭循环 | `arrow.triangle.2.circlepath` | inkMist | 播完最后一首暂停 |
| 列表循环 | `repeat` | cobalt | 循环播放整个列表 |
| 单曲循环 | `repeat.1` | cobalt | 重复播放当前歌曲 |
| 随机播放 | `shuffle` | cobalt(开)/inkMist(关) | Fisher-Yates 打乱 |

### 9.3 上一首/下一首

| 操作 | 条件 | 行为 |
|------|------|------|
| 上一首 | 播放 > 3秒 | 从头播放当前歌曲 |
| 上一首 | 播放 < 3秒 | 跳到上一首 |
| 下一首 | 单曲循环 | 跳到下一首（不循环当前） |
| 下一首 | 顺序模式 | 下一首，末尾暂停 |
| 下一首 | 列表循环 | 下一首，末尾回第一首 |

---

## 10. Swift 代码模式

### 10.1 标准按钮样式

```swift
Button(action: { ... }) {
    // 内容
}
.buttonStyle(.plain)
```

### 10.2 标准文字样式

```swift
// 主文字
.font(.system(size: 15, weight: .medium))
.foregroundColor(QingYinColors.ink)
.lineLimit(1)

// 辅助文字
.font(.system(size: 12))
.foregroundColor(QingYinColors.inkMist)
.lineLimit(1)

// 时间文字
.font(.system(size: 9))
.foregroundColor(QingYinColors.inkMist)
.monospacedDigit()
```

### 10.3 标准描边背景

```swift
.background(QingYinColors.porcelain)
.overlay(
    RoundedRectangle(cornerRadius: 6)
        .stroke(QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
)
```

### 10.4 标准分隔线

```swift
.overlay(
    Rectangle()
        .fill(QingYinColors.cobalt.opacity(0.06))
        .frame(height: 1)
    , alignment: .top  // 或 .bottom
)
```

### 10.5 选中高亮

```swift
.background(isSelected ? QingYinColors.cobaltGhost : Color.clear)
.foregroundColor(isSelected ? QingYinColors.cobalt : QingYinColors.inkLight)
```

### 10.6 Filter Chip

```swift
.padding(.horizontal, 12)
.padding(.vertical, 5)
.background(isSelected ? QingYinColors.cobalt : Color.clear)
.foregroundColor(isSelected ? Color.white : QingYinColors.inkLight)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(isSelected ? QingYinColors.cobalt : QingYinColors.cobalt.opacity(0.12), lineWidth: 1)
)
.cornerRadius(16)
```

---

## 11. 图标尺寸规范

| 场景 | 字号 | 颜色 |
|------|------|------|
| 底部栏控制图标（前后） | 13pt | ink |
| 底部栏播放/暂停 | 16pt | cobalt |
| 底部栏随机/循环 | 11pt | cobalt(开) / inkMist(关) |
| 底部栏音量图标 | 11pt | inkMist |
| 侧栏图标 | 13pt | cobalt(选中) / inkLight(未选中) |
| 排序方向箭头 | 8pt | cobalt |
| 搜索图标 | 12pt | inkMist |
| NowPlaying 控制（前后） | 18pt | ink |
| NowPlaying 播放/暂停 | 22pt | cobalt |
| NowPlaying 随机/循环 | 16pt | cobalt(开) / inkMist(关) |
| 空状态占位图标 | 40pt .light | cobalt.opacity(0.3) |

---

*本文件由代码库自动统计生成，最后更新：2026-08-26*
