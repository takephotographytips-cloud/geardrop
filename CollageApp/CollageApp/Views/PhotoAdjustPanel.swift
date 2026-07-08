import SwiftUI

/// 選択中の写真1枚に対する調整パネル（Stack Pro: 水平・回転補正）。
/// コラージュ上の写真をタップすると AdjustPanel と入れ替わりで表示される。
/// - 水平: ±15° の微調整スライダー（傾けても背景が見えないよう自動でわずかに拡大）
/// - 90°回転: 縦横の入れ替え
/// - リセット: ズーム・位置・回転を初期化
struct PhotoAdjustPanel: View {
    @Bindable var viewModel: EditorViewModel
    let store: PresetStore
    let photoID: UUID
    /// 未購入時にロック行をタップしたときに呼ばれる（ペイウォール表示）
    var onRequestPro: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label(headerTitle, systemImage: "crop.rotate")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("完了") {
                    viewModel.selectedPhotoID = nil
                }
                .font(.subheadline.weight(.semibold))
            }

            if store.isPro {
                // 水平微調整（±15°）
                HStack(spacing: 12) {
                    Text("水平")
                        .font(.subheadline)
                        .frame(width: 44, alignment: .leading)
                    Slider(value: fineAngleSelection, in: CellGeometry.fineAngleRange) { editing in
                        if editing {
                            viewModel.registerUndoSnapshot()
                        }
                    }
                    Text("\(Int(fineAngleSelection.wrappedValue.rounded()))°")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Button {
                        viewModel.rotateQuarter(for: photoID)
                    } label: {
                        Label("90°回転", systemImage: "rotate.right")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.resetTransform(for: photoID)
                    } label: {
                        Label("リセット", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            } else {
                Button {
                    onRequestPro()
                } label: {
                    HStack {
                        Label("水平・回転補正は Stack Pro で解放", systemImage: "lock.fill")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Text("ドラッグで移動・ピンチで拡大縮小できます")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var headerTitle: String {
        if let index = viewModel.selectedPhotoIndex {
            return "写真の調整（\(index + 1)枚目）"
        }
        return "写真の調整"
    }

    /// 水平微調整の Binding。90°単位の成分は維持し、微調整成分のみ変更する。
    private var fineAngleSelection: Binding<Double> {
        Binding {
            viewModel.transform(for: photoID).fineAngleDegrees
        } set: { newValue in
            viewModel.setFineAngle(newValue, for: photoID)
        }
    }
}
