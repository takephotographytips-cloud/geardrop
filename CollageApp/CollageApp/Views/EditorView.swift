import SwiftUI

/// 画面B: エディタ（仕様 2.2 / v1.1 変更）。
/// 上部: プレビュー（セル内の写真をドラッグ・ピンチで直接編集）/
/// 中部: レイアウト切替（縦並び・横並び）/ 下部: 調整パネル / 右上: 保存。
/// タップ3: 保存ボタンでフォトライブラリへ書き出して完了。
struct EditorView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 16) {
            CollageCanvasView(viewModel: viewModel)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .frame(maxHeight: .infinity)

            Picker("レイアウト", selection: layoutSelection) {
                ForEach(Array(viewModel.layouts.enumerated()), id: \.offset) { index, layout in
                    Text(layout.displayName).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            AdjustPanel(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    viewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)

                Button {
                    viewModel.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)
            }

            ToolbarItem(placement: .topBarTrailing) {
                saveButton
            }
        }
        .overlay {
            if viewModel.saveState == .saved {
                savedToast
            }
        }
        .alert(
            "保存に失敗しました",
            isPresented: saveFailedBinding,
            actions: { Button("OK") { viewModel.saveState = .idle } },
            message: {
                if case .failed(let message) = viewModel.saveState {
                    Text(message)
                }
            }
        )
    }

    /// レイアウト切替。写真データと各セルの変形状態は維持される
    /// （オフセットは正規化保持のため、新しいセルサイズで再クランプされる）。
    private var layoutSelection: Binding<Int> {
        Binding {
            viewModel.layoutIndex
        } set: { newValue in
            guard newValue != viewModel.layoutIndex else { return }
            viewModel.registerUndoSnapshot()
            viewModel.layoutIndex = newValue
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveToPhotoLibrary()
                if viewModel.saveState == .saved {
                    try? await Task.sleep(for: .seconds(1.5))
                    if viewModel.saveState == .saved {
                        viewModel.saveState = .idle
                    }
                }
            }
        } label: {
            if viewModel.saveState == .saving {
                ProgressView()
            } else {
                Text("保存")
                    .fontWeight(.semibold)
            }
        }
        .disabled(viewModel.saveState == .saving || viewModel.photos.isEmpty)
    }

    private var savedToast: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("保存しました")
                .font(.subheadline)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .transition(.opacity)
    }

    private var saveFailedBinding: Binding<Bool> {
        Binding {
            if case .failed = viewModel.saveState { return true }
            return false
        } set: { presented in
            if !presented { viewModel.saveState = .idle }
        }
    }
}
