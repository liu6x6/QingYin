//
//  EqualizerSettings.swift
//  本地音乐十段均衡器配置
//

import Foundation

enum EqualizerPreset: String, CaseIterable, Codable, Identifiable {
    case flat
    case acoustic
    case pop
    case rock
    case classical
    case jazz
    case bassBoost
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flat: return "原声"
        case .acoustic: return "原声乐器"
        case .pop: return "流行"
        case .rock: return "摇滚"
        case .classical: return "古典"
        case .jazz: return "爵士"
        case .bassBoost: return "低音增强"
        case .custom: return "自定义"
        }
    }
}

struct EqualizerBand: Codable, Identifiable, Equatable {
    static let gainRange: ClosedRange<Float> = -12...12

    let frequency: Float
    var gain: Float

    var id: Float { frequency }

    init(frequency: Float, gain: Float = 0) {
        self.frequency = frequency
        self.gain = Self.clamp(gain)
    }

    static func clamp(_ gain: Float) -> Float {
        min(max(gain, gainRange.lowerBound), gainRange.upperBound)
    }
}

struct EqualizerSettings: Codable, Equatable {
    static let preampRange: ClosedRange<Float> = -12...12
    static let frequencies: [Float] = [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]

    var isEnabled: Bool
    var preset: EqualizerPreset
    var preampGain: Float
    var bands: [EqualizerBand]

    static let `default` = EqualizerSettings(
        isEnabled: false,
        preset: .flat,
        preampGain: 0,
        bands: frequencies.map { EqualizerBand(frequency: $0) }
    )

    init(isEnabled: Bool, preset: EqualizerPreset, preampGain: Float, bands: [EqualizerBand]) {
        self.isEnabled = isEnabled
        self.preset = preset
        self.preampGain = Self.clampPreamp(preampGain)
        self.bands = Self.normalizedBands(bands)
    }

    static func presetSettings(for preset: EqualizerPreset, isEnabled: Bool = true) -> EqualizerSettings {
        let gains: [Float]
        let preamp: Float

        switch preset {
        case .flat, .custom:
            gains = Array(repeating: 0, count: frequencies.count)
            preamp = 0
        case .acoustic:
            gains = [-1, 0, 1, 2, 2, 1, 1, 2, 2, 1]
            preamp = -2
        case .pop:
            gains = [-1, 1, 3, 4, 2, 0, -1, 1, 3, 4]
            preamp = -4
        case .rock:
            gains = [4, 3, 1, -1, -2, 1, 3, 4, 4, 3]
            preamp = -5
        case .classical:
            gains = [3, 2, 1, 0, -1, 0, 2, 3, 4, 4]
            preamp = -4
        case .jazz:
            gains = [2, 1, 0, 1, -1, -1, 0, 2, 3, 3]
            preamp = -3
        case .bassBoost:
            gains = [6, 5, 3, 1, 0, 0, 0, -1, -1, -1]
            preamp = -6
        }

        return EqualizerSettings(
            isEnabled: isEnabled,
            preset: preset,
            preampGain: preamp,
            bands: zip(frequencies, gains).map { EqualizerBand(frequency: $0.0, gain: $0.1) }
        )
    }

    static func clampPreamp(_ gain: Float) -> Float {
        min(max(gain, preampRange.lowerBound), preampRange.upperBound)
    }

    private static func normalizedBands(_ bands: [EqualizerBand]) -> [EqualizerBand] {
        frequencies.map { frequency in
            EqualizerBand(
                frequency: frequency,
                gain: bands.first(where: { $0.frequency == frequency })?.gain ?? 0
            )
        }
    }
}
