import PhotosUI
import SwiftUI

/// 画面A: ホーム（仕様 2.2）。
/// タップ1: 起動直後に PhotosPicker が開き、写真を2〜6枚選択する（選んだ順＝配置順）。
struct HomeView: View {
    @State private var viewModel = EditorViewModel()
    @State private var presetStore = PresetStore()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isPickerPresented = false
    @State private var showEditor = false
    @State private var didAutoPresentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Button {
                    isPickerPresented = true
                } label: {
                    Label("写真を選ぶ", systemImage: "plus")
                        .font(.title2.weight(.medium))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                Text("2〜6枚を選ぶと自動でレイアウトします")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                // 保存済みプリセット一覧（横スクロール）。保存 UI は Phase 3 で追加。
                if !presetStore.presets.isEmpty {
                    presetRow
                }
            }
            .padding()
            .navigationTitle("Stack")
            .navigationDestination(isPresented: $showEditor) {
                EditorView(viewModel: viewModel)
            }
            .photosPicker(
                isPresented: $isPickerPresented,
                selection: $pickerItems,
                maxSelectionCount: 6,
                selectionBehavior: .ordered,
                matching: .images
            )
            .onChange(of: isPickerPresented) { _, presented in
                guard !presented else { return }
                openEditorIfReady()
            }
            .onAppear {
                // タップ1を最短にするため、初回起動時はピッカーを自動で開く（仕様 2.1）
                if !didAutoPresentPicker {
                    didAutoPresentPicker = true
                    isPickerPresented = true
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("読み込み中…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var presetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プリセット")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetStore.presets) { preset in
                        Text(preset.name)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }

    private func openEditorIfReady() {
        let items = pickerItems
        guard items.count >= 2 else {
            pickerItems = []
            return
        }
        Task {
            await viewModel.loadPhotos(from: items)
            pickerItems = []
            if viewModel.photos.count >= 2 {
                showEditor = true
            }
        }
    }
}

#Preview {
    HomeView()
}
