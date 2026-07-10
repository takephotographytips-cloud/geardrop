import SwiftUI

/// 調整パネル（仕様 2.2: 引き算思想）。
/// 余白 / 間隔 / 色（プリセット3色 + カラーピッカー※スポイト内蔵）/ 比率 / フレーム（Pro）
struct AdjustPanel: View {
    @Bindable var viewModel: EditorViewModel
    let store: PresetStore
    /// ロック中のフレームをタップしたときに呼ばれる（ペイウォール表示）
    var onRequestPro: () -> Void

    @Environment(CoachMarksController.self) private var coachMarks

    private let presetColors: [(color: CanvasColor, name: String)] = [
        (.white, "白"),
        (.black, "黒"),
        (.offWhite, "オフホワイト"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // 余白: スライダー（0〜15%）
            sliderRow(
                label: "余白",
                value: $viewModel.spec.marginFraction,
                range: CanvasSpec.marginRange,
                onEditingEnded: { coachMarks.noteAction(.marginChanged) }
            )
            .coachMarkTarget(.marginSlider)

            // 間隔: 写真同士のガター幅（0〜10%）
            sliderRow(
                label: "間隔",
                value: $viewModel.spec.gutterFraction,
                range: CanvasSpec.gutterRange
            )

            // 余白色: プリセット3色 + カラーピッカー（スポイトで写真から色を拾える）
            HStack(spacing: 12) {
                Text("色")
                    .font(.subheadline)
                    .frame(width: 44, alignment: .leading)
                ForEach(presetColors, id: \.name) { preset in
                    Button {
                        guard viewModel.spec.background != preset.color else { return }
                        viewModel.registerUndoSnapshot()
                        viewModel.spec.background = preset.color
                    } label: {
                        Circle()
                            .fill(preset.color.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().strokeBorder(.quaternary, lineWidth: 1)
                            )
                            .overlay {
                                if viewModel.spec.background == preset.color {
                                    Circle()
                                        .strokeBorder(.tint, lineWidth: 2)
                                        .padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                }
                ColorPicker("背景色", selection: customColorSelection, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
            }

            // 比率: セグメント切替（枠は固定、写真はカバーフィット）
            HStack(spacing: 12) {
                Text("比率")
                    .font(.subheadline)
                    .frame(width: 44, alignment: .leading)
                Picker("比率", selection: ratioSelection) {
                    ForEach(CanvasRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
            }

            // フレーム: なしは無料、デザインフレームは Stack Pro
            HStack(spacing: 12) {
                Text("フレーム")
                    .font(.subheadline)
                    .frame(width: 44, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FrameStyle.allCases) { style in
                            frameChip(style)
                        }
                    }
                }
            }
        }
    }

    private func frameChip(_ style: FrameStyle) -> some View {
        let isSelected = viewModel.spec.frame == style
        let isLocked = style.isPro && !store.isPro
        return Button {
            if isLocked {
                onRequestPro()
                return
            }
            guard !isSelected else { return }
            viewModel.registerUndoSnapshot()
            viewModel.spec.frame = style
        } label: {
            HStack(spacing: 4) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                Text(style.displayName)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
            .overlay {
                if isSelected {
                    Capsule().strokeBorder(.tint, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sliderRow(
        label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        onEditingEnded: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(width: 44, alignment: .leading)
            Slider(value: value, in: range) { editing in
                if editing {
                    viewModel.registerUndoSnapshot()
                } else {
                    onEditingEnded?()
                }
            }
            Text(Double(value.wrappedValue), format: .percent.precision(.fractionLength(0)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var customColorSelection: Binding<Color> {
        Binding {
            viewModel.spec.background.color
        } set: { newValue in
            let newColor = CanvasColor(newValue)
            guard newColor != viewModel.spec.background else { return }
            viewModel.registerUndoSnapshot()
            viewModel.spec.background = newColor
        }
    }

    private var ratioSelection: Binding<CanvasRatio> {
        Binding {
            viewModel.spec.ratio
        } set: { newValue in
            guard newValue != viewModel.spec.ratio else { return }
            viewModel.registerUndoSnapshot()
            viewModel.spec.ratio = newValue
        }
    }
}
