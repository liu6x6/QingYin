# 均衡器设计方案

## 范围

清音仅播放用户导入或扫描到的本地音乐文件。本设计不支持 Apple Music 订阅曲目、流媒体或 DRM 内容；`AppleMusicMacService` 后续不再作为均衡器播放链路的输入。

第一期交付：

- 10 段图示均衡器
- 开关、预放大、重置
- 预设与自定义配置
- 配置持久化
- iOS、iPadOS 和 macOS 的一致体验

## 播放架构

当前 `AudioPlayerManager` 以 `AVPlayer` 为播放核心。`AVPlayer` 不能直接串接 `AVAudioUnitEQ`，因此本地播放应迁移为下列音频图：

```text
AVAudioFile
    |
AVAudioPlayerNode
    |
AVAudioUnitEQ (10 bands)
    |
AVAudioEngine.mainMixerNode
    |
硬件输出
```

`AudioPlayerManager` 继续负责队列、随机、循环、进度、播放状态和持久化；新增的本地音频引擎负责加载、播放、暂停、定位和应用音效。切歌时保留 EQ 节点和当前配置，只更换 `AVAudioFile` 与调度内容，避免音效参数闪动。

## 数据模型

新增 `Models/EqualizerSettings.swift`：

```swift
enum EqualizerPreset: String, CaseIterable, Codable {
    case flat, acoustic, pop, rock, classical, jazz, bassBoost, custom
}

struct EqualizerBand: Codable, Identifiable, Equatable {
    let frequency: Float
    var gain: Float
    var id: Float { frequency }
}

struct EqualizerSettings: Codable, Equatable {
    var isEnabled: Bool
    var preset: EqualizerPreset
    var preampGain: Float
    var bands: [EqualizerBand]
}
```

频段使用 32、64、125、250、500、1k、2k、4k、8k、16k Hz。每段增益和预放大均限制在 -12 至 +12 dB；Q 值固定为 1.0，滤波器类型为 `parametric`。

预设保存一份不可变的频段模板。用户拖动任一频段或预放大后，当前预设立即变更为 `custom`。配置以单个 JSON 值保存到 `UserDefaults`，键名为 `qingyin.equalizerSettings`。

## 对外接口

`AudioPlayerManager` 新增：

```swift
@Published private(set) var equalizerSettings: EqualizerSettings

func setEqualizerEnabled(_ isEnabled: Bool)
func selectEqualizerPreset(_ preset: EqualizerPreset)
func setEqualizerGain(_ gain: Float, at index: Int)
func setPreampGain(_ gain: Float)
func resetEqualizer()
```

每一个设置方法均在主线程更新发布状态、同步更新 `AVAudioUnitEQ`，再持久化。音频引擎尚未创建时，只更新模型；下一次加载歌曲时一次性将最新配置应用到节点。

## 界面设计

入口位于：

- `SettingsView` 的“播放”分组：`均衡器` 行，显示当前预设名称或“关闭”。
- `NowPlayingView` 的更多菜单：`均衡器` 快捷入口。

均衡器页按以下顺序排列：

1. 导航栏：返回、标题“均衡器”。
2. 主开关：关闭时显示当前配置但禁用编辑，避免用户丢失调音。
3. 预设胶囊按钮：原声、流行、摇滚、古典、爵士、低音增强和自定义。
4. 频段调节器：十根纵向滑杆，中央为 0 dB 基线，顶部 +12 dB，底部 -12 dB；每根显示频率和实时 dB 数值。
5. 预放大：横向滑杆和数值。
6. 重置：恢复“原声”预设并启用均衡器。

颜色沿用 `QingYinColors`：瓷白背景、钴蓝作为激活轨道与预设、青瓷用于辅助数值、墨色用于正文。纵向滑杆采用细线和圆形拖拽点，呼应唱片与青花瓷纹样的轻盈感。

## 实施顺序

1. 添加模型、预设模板与持久化测试。
2. 实现 `LocalAudioEngine`，并以本地文件验证播放、暂停、定位、切歌和 EQ 更新。
3. 将 `AudioPlayerManager` 的本地播放逻辑迁移到该引擎，保持现有队列行为。
4. 添加 `EqualizerView`，接入设置页和正在播放页。
5. 为预设映射、增益边界、持久化恢复及切歌后配置保持添加单元测试。

## 验收标准

- 本地歌曲播放期间拖动任意频段，声音立即变化且不中断。
- 所有频段与预放大永远不超过 -12 至 +12 dB。
- 重启应用、暂停恢复和切换歌曲后，均衡器配置保持一致。
- 关闭均衡器时音频不经过 EQ 增益处理；再次开启后恢复原配置。
