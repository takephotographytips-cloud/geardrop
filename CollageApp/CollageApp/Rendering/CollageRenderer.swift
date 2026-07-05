import UIKit

/// プレビュー解像度のコラージュ合成（仕様 3.2: 表示用は長辺2048px）。
/// Phase 1 の書き出しもこのレンダラを使う。フル解像度・16bit 合成は Phase 2 の
/// ExportRenderer で置き換える。
///
/// 各写真はセルにカバーフィット（BoxFit.cover 相当）し、セル矩形でクリップして描画する。
/// 矩形計算はプレビューと同じ `CellGeometry` を使い、画面と書き出しの見た目を一致させる。
enum CollageRenderer {

    /// 指定レイアウト・設定・変形状態で1枚の UIImage に合成する。
    /// - Parameters:
    ///   - transforms: 写真と同順の変形状態。不足分はデフォルト（カバー・中央）。
    ///   - longSide: 出力キャンバスの長辺ピクセル数
    static func render(
        images: [UIImage],
        transforms: [CellTransform],
        layout: CollageLayout,
        spec: CanvasSpec,
        longSide: CGFloat = 2048
    ) -> UIImage {
        let canvasSize = spec.ratio.size(longSide: longSide)
        let cells = layout.cellRects(canvasSize: canvasSize, spec: spec, count: images.count)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { context in
            let rgba = spec.background.rgba
            UIColor(
                red: rgba.red,
                green: rgba.green,
                blue: rgba.blue,
                alpha: rgba.alpha
            ).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            for (index, image) in images.enumerated() {
                guard cells.indices.contains(index), image.size.height > 0 else { continue }
                let cell = cells[index]
                let transform = transforms.indices.contains(index) ? transforms[index] : CellTransform()
                let imageRect = CellGeometry.imageRect(
                    imageRatio: image.size.width / image.size.height,
                    cell: cell,
                    transform: transform
                )
                context.cgContext.saveGState()
                context.cgContext.clip(to: cell)
                image.draw(in: imageRect)
                context.cgContext.restoreGState()
            }
        }
    }
}
