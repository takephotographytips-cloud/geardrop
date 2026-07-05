import PhotosUI
import SwiftUI

/// 画面A: ホーム（仕様 2.2）。
/// タップ1: 起動直後に PhotosPicker が開き、写真を1〜6枚選択する（選んだ順＝配置順）。
/// 下部に保存済みプリセット＋購入済みパックのプリセットを横スクロールで表示し、
/// タップするとそのプリセットを適用した状態で写真選択に進む。
struct HomeView: View {
    @State private var viewModel = EditorViewModel()
    @State private var presetStore = PresetStore()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isPickerPresented = false
    @State private var showEditor = false
    @State private var showSettings = false
    @State private var didAutoPresentPicker = false
    @State private var pendingPreset: Preset?
    @State private var hasStoredSession = false

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

                Text("1〜6枚を選ぶと自動でレイアウトします")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if canResume {
                    Button {
                        resumeSession()
                    } label: {
                        Label("前回の編集を再開", systemImage: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                presetSection
            }
            .padding()
            .navigationTitle("Stack")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: presetStore)
            }
            .navigationDestination(isPresented: $showEditor) {
                EditorView(viewModel: viewModel, presetStore: presetStore)
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
                hasStoredSession = SessionStore.hasSession()
                // タップ1を最短にするため初回はピッカーを自動で開く（仕様 2.1）。
                // ただし再開できるセッションがあるときは選択を邪魔しない。
                if !didAutoPresentPicker, !canResume {
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

    // MARK: - プリセット一覧

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プリセット")
                .font(.headline)
            if presetStore.presets.isEmpty {
                Text("エディタ右上のしおりボタンで、現在の設定をプリセットとして保存できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presetStore.presets) { preset in
                            presetChip(preset)
                        }
                    }
                }
            }
        }
    }

    private func presetChip(_ preset: Preset) -> some View {
        Button {
            pendingPreset = preset
            isPickerPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(preset.name, systemImage: preset.layout.symbolName)
                    .font(.subheadline)
                Text("\(preset.spec.ratio.rawValue)・余白\(Int((preset.spec.marginFraction * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("削除", role: .destructive) {
                presetStore.remove(preset)
            }
        }
    }

    // MARK: - フロー

    private var canResume: Bool {
        hasStoredSession || !viewModel.photos.isEmpty
    }

    private func resumeSession() {
        // メモリ上に編集中の状態があればそのまま戻る。なければディスクから復元。
        if !viewModel.photos.isEmpty {
            showEditor = true
            return
        }
        Task {
            if await viewModel.restoreSessionFromDisk() {
                showEditor = true
            } else {
                SessionStore.clear()
                hasStoredSession = false
            }
        }
    }

    private func openEditorIfReady() {
        let items = pickerItems
        guard !items.isEmpty else {
            pickerItems = []
            pendingPreset = nil
            return
        }
        Task {
            await viewModel.loadPhotos(from: items)
            pickerItems = []
            if !viewModel.photos.isEmpty {
                if let preset = pendingPreset {
                    viewModel.apply(preset: preset)
                }
                hasStoredSession = true
                showEditor = true
            }
            pendingPreset = nil
        }
    }
}

#Preview {
    HomeView()
}
