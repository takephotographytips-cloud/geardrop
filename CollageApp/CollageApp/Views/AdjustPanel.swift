import SwiftUI

/// 調整パネル（仕様 2.2: 引き算思想、Phase 1 は余白＋色＋比率のみ）。
/// ガター（間隔）スライダーとスポイト・カラーピッカーは Phase 2 で追加する。
struct AdjustPanel: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 余白: スライダー（0〜15%）
            HStack(spacing: 12) {
                Text("余白")
                    .font(.subheadline)
                    .frame(width: 44, alignment: .leading)
                Slider(
                    value: $viewModel.spec.marginFraction,
                    in: CanvasSpec.marginRange
                ) { editing in
                    if editing {
                        viewModel.registerUndoSnapshot()
                    }
                }
                Text(Double(viewModel.spec.marginFraction), format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            // 余白色: 白 / 黒 / オフホワイト #F5F2ED
            HStack(spacing: 12) {
                Text("色")
                    .font(.subheadline)
                    .frame(width: 44, alignment: .leading)
                ForEach(BackgroundColorChoice.allCases) { choice in
                    Button {
                        guard viewModel.spec.background != choice else { return }
                        viewModel.registerUndoSnapshot()
                        viewModel.spec.background = choice
                    } label: {
                        Circle()
                            .fill(choice.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().strokeBorder(.quaternary, lineWidth: 1)
                            )
                            .overlay {
                                if viewModel.spec.background == choice {
                                    Circle()
                                        .strokeBorder(.tint, lineWidth: 2)
                                        .padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.displayName)
                }
                Spacer()
            }

            // 比率: セグメント切替（写真はトリミングせずフィット）
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
