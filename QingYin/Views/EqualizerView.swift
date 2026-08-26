//
//  EqualizerView.swift
//  本地音乐均衡器
//

import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    let showsDismissButton: Bool

    init(showsDismissButton: Bool = true) {
        self.showsDismissButton = showsDismissButton
    }

    private var settings: EqualizerSettings {
        playerViewModel.equalizerSettings
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QingYinColors.porcelain.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Toggle(isOn: Binding(
                            get: { settings.isEnabled },
                            set: { playerViewModel.setEqualizerEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("开启音效")
                                    .foregroundColor(QingYinColors.ink)
                                Text(settings.isEnabled ? "正在应用 \(settings.preset.displayName) 设置" : "保留当前设置，不处理音频")
                                    .font(.system(size: 12))
                                    .foregroundColor(QingYinColors.inkMist)
                            }
                        }
                        .tint(QingYinColors.cobalt)

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("预设")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(EqualizerPreset.allCases.filter { $0 != .custom }) { preset in
                                        Button(preset.displayName) {
                                            playerViewModel.selectEqualizerPreset(preset)
                                        }
                                        .buttonStyle(EqualizerPresetButtonStyle(isSelected: settings.preset == preset))
                                        .disabled(!settings.isEnabled)
                                    }
                                    if settings.preset == .custom {
                                        Text(EqualizerPreset.custom.displayName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(QingYinColors.cobalt)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(QingYinColors.cobaltGhost)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                sectionTitle("频率")
                                Spacer()
                                Text("0 dB")
                                    .font(.system(size: 13))
                                    .foregroundColor(QingYinColors.celadon)
                            }

                            EqualizerBandsView(
                                bands: settings.bands,
                                isEnabled: settings.isEnabled,
                                onGainChanged: { index, gain in
                                    playerViewModel.setEqualizerGain(gain, at: index)
                                }
                            )
                            .frame(height: 270)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                sectionTitle("预放大")
                                Spacer()
                                Text(formattedGain(settings.preampGain))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(QingYinColors.celadon)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(settings.preampGain) },
                                    set: { playerViewModel.setPreampGain(Float($0)) }
                                ),
                                in: Double(EqualizerSettings.preampRange.lowerBound)...Double(EqualizerSettings.preampRange.upperBound),
                                step: 0.5
                            )
                            .tint(QingYinColors.cobalt)
                            .disabled(!settings.isEnabled)
                        }

                        Button(action: playerViewModel.resetEqualizer) {
                            Text("重置为原声")
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundColor(QingYinColors.cobalt)
                                .background(QingYinColors.porcelainDeep)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("均衡器")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("完成") { dismiss() }
                            .foregroundColor(QingYinColors.cobalt)
                    }
                }
            }
            #else
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(QingYinColors.inkMist)
    }

    private func formattedGain(_ gain: Float) -> String {
        String(format: "%+.1f dB", gain)
    }
}

private struct EqualizerBandsView: View {
    let bands: [EqualizerBand]
    let isEnabled: Bool
    let onGainChanged: (Int, Float) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(QingYinColors.celadon.opacity(0.65))
                        .frame(height: 1)
                    Spacer()
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                        EqualizerBandSlider(
                            band: band,
                            isEnabled: isEnabled,
                            onGainChanged: { onGainChanged(index, $0) }
                        )
                        .frame(width: geometry.size.width / CGFloat(max(bands.count, 1)))
                    }
                }
            }
        }
    }
}

private struct EqualizerBandSlider: View {
    let band: EqualizerBand
    let isEnabled: Bool
    let onGainChanged: (Float) -> Void

    var body: some View {
        GeometryReader { geometry in
            let trackTop: CGFloat = 24
            let trackHeight = max(1, geometry.size.height - 74)
            let normalizedGain = CGFloat((band.gain - EqualizerBand.gainRange.lowerBound) /
                (EqualizerBand.gainRange.upperBound - EqualizerBand.gainRange.lowerBound))
            let thumbY = trackTop + (1 - normalizedGain) * trackHeight
            let baselineY = trackTop + trackHeight / 2

            VStack(spacing: 0) {
                Text(formattedGain(band.gain))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isEnabled ? QingYinColors.celadon : QingYinColors.inkMist)
                    .frame(height: 20)

                ZStack(alignment: .top) {
                    Capsule()
                        .fill(QingYinColors.porcelainDeep)
                        .frame(width: 5, height: trackHeight)

                    Rectangle()
                        .fill(QingYinColors.cobalt)
                        .frame(width: 5, height: abs(thumbY - baselineY))
                        .offset(y: min(thumbY, baselineY) - trackTop)

                    Circle()
                        .fill(isEnabled ? QingYinColors.cobalt : QingYinColors.inkMist)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        .offset(y: thumbY - trackTop - 8)
                }
                .frame(height: trackHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard isEnabled else { return }
                            let position = min(max(0, value.location.y), trackHeight)
                            let normalized = 1 - (position / trackHeight)
                            let gain = EqualizerBand.gainRange.lowerBound +
                                Float(normalized) * (EqualizerBand.gainRange.upperBound - EqualizerBand.gainRange.lowerBound)
                            onGainChanged(gain)
                        }
                )

                Text(frequencyLabel(band.frequency))
                    .font(.system(size: 11))
                    .foregroundColor(QingYinColors.ink)
                    .frame(height: 30, alignment: .bottom)
            }
        }
    }

    private func formattedGain(_ gain: Float) -> String {
        String(format: "%+.0f", gain)
    }

    private func frequencyLabel(_ frequency: Float) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }
}

private struct EqualizerPresetButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isSelected ? QingYinColors.porcelain : QingYinColors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? QingYinColors.cobalt : QingYinColors.porcelainDeep)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
