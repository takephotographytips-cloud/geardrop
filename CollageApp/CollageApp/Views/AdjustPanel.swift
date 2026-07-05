import SwiftUI

/// 調整パネル（仕様 2.2: 引き算思想の3項目）。
/// 1. 余白: スライダー + 色（プリセット3色 + カラーピッカー※スポイト内蔵）
/// 2. 比率: セグメント切替
/// 3. 間隔: 写真同士のガター幅スライダー
struct AdjustPanel: View {
    @Bindable var viewModel: EditorViewModel

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
                range: CanvasSpec.marginRange
            )

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
        }
    }

    private func sliderRow(
        label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(width: 44, alignment: .leading)
            Slider(value: value, in: range) { editing in
                if editing {
                    viewModel.registerUndoSnapshot()
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
