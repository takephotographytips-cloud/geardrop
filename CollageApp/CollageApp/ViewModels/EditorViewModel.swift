import ImageIO
import Observation
import PhotosUI
import SwiftUI

/// エディタの状態。写真（プレビュー用にダウンサンプル済み）・レイアウト候補・
/// キャンバス設定・Undo/Redo スタックを持つ。
@Observable
@MainActor
final class EditorViewModel {

    /// 選択写真。image はプレビュー用（長辺2048px、仕様 3.2）。
    struct Photo: Identifiable {
        let id = UUID()
        let image: UIImage

        /// 幅 ÷ 高さ
        var aspectRatio: CGFloat {
            guard image.size.height > 0 else { return 1 }
            return image.size.width / image.size.height
        }
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    private(set) var photos: [Photo] = []
    var spec = CanvasSpec()
    var layoutIndex = 0
    private(set) var isLoading = false
    var saveState: SaveState = .idle

    /// セルごとの写真変形状態（写真 ID キー）。
    /// レイアウトを変更してもズーム率・位置を維持できるよう、セル位置ではなく写真に紐付ける。
    var transforms: [UUID: CellTransform] = [:]

    /// 選択枚数に応じたレイアウト候補
    var layouts: [CollageLayout] {
        CollageLayout.candidates(for: photos.count)
    }

    var currentLayout: CollageLayout? {
        let layouts = layouts
        guard layouts.indices.contains(layoutIndex) else { return layouts.first }
        return layouts[layoutIndex]
    }

    /// 表示順に並べた変形状態（レンダラへ渡す用）
    var orderedTransforms: [CellTransform] {
        photos.map { transforms[$0.id] ?? CellTransform() }
    }

    // MARK: - 写真読み込み

    /// PhotosPicker の選択結果を読み込む。選んだ順＝配置順（仕様 2.1）。
    /// メモリ対策として1枚ずつ順次読み込み、長辺2048pxへダウンサンプルする。
    func loadPhotos(from items: [PhotosPickerItem]) async {
        isLoading = true
        defer { isLoading = false }
        var loaded: [Photo] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = Self.downsample(data: data, maxPixelSize: 2048) else { continue }
            loaded.append(Photo(image: image))
        }
        photos = loaded
        layoutIndex = 0
        transforms = [:]
        undoStack.removeAll()
        redoStack.removeAll()
        saveState = .idle
    }

    /// CGImageSource でフルデコードせずにダウンサンプルする（メモリ対策、仕様 3.2）。
    nonisolated static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - 保存

    /// タップ3: フォトライブラリへ書き出す。
    /// Phase 1 はプレビュー解像度（長辺2048px）で可（仕様 Phase 1）。
    /// フル解像度・16bit 合成・EXIF 保持は Phase 2 の ExportRenderer で対応する。
    func saveToPhotoLibrary() async {
        guard let layout = currentLayout, !photos.isEmpty else { return }
        saveState = .saving
        do {
            try await ExportRenderer.export(
                images: photos.map(\.image),
                transforms: orderedTransforms,
                layout: layout,
                spec: spec
            )
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Undo / Redo（仕様 2.2: 最初から入れる）

    private struct Snapshot: Equatable {
        var spec: CanvasSpec
        var layoutIndex: Int
        var transforms: [UUID: CellTransform]
    }

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// 設定・写真を変更する直前に呼ぶ（スライダー・ジェスチャーは開始時に1回）。
    func registerUndoSnapshot() {
        let snapshot = currentSnapshot()
        if undoStack.last != snapshot {
            undoStack.append(snapshot)
            redoStack.removeAll()
        }
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        apply(snapshot)
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        apply(snapshot)
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(spec: spec, layoutIndex: layoutIndex, transforms: transforms)
    }

    private func apply(_ snapshot: Snapshot) {
        spec = snapshot.spec
        layoutIndex = snapshot.layoutIndex
        transforms = snapshot.transforms
    }
}
