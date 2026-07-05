import Photos
import UIKit

/// フォトライブラリへの書き出し。
///
/// Phase 1: プレビュー解像度（長辺2048px）の合成をそのまま保存する（仕様 Phase 1 で許容）。
/// Phase 2: 元画像フル解像度を CGContext で順次合成（16bit・Display P3・EXIF 保持）に置き換える。
enum ExportRenderer {

    enum ExportError: LocalizedError {
        case photoLibraryAccessDenied

        var errorDescription: String? {
            switch self {
            case .photoLibraryAccessDenied:
                return "フォトライブラリへのアクセスが許可されていません。設定から追加のみのアクセスを許可してください。"
            }
        }
    }

    /// 合成してフォトライブラリに追加する（追加のみの権限を要求、全権限は要求しない）。
    static func export(
        images: [UIImage],
        layout: CollageLayout,
        spec: CanvasSpec,
        longSide: CGFloat = 2048
    ) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photoLibraryAccessDenied
        }

        let rendered = CollageRenderer.render(
            images: images,
            layout: layout,
            spec: spec,
            longSide: longSide
        )

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: rendered)
        }
    }
}
