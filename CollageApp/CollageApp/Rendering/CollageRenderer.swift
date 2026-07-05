import UIKit

/// プレビュー解像度のコラージュ合成（仕様 3.2: 表示用は長辺2048px）。
/// Phase 1 の書き出しもこのレンダラを使う。フル解像度・16bit 合成は Phase 2 の
/// ExportRenderer で置き換える。
enum CollageRenderer {

    /// 指定レイアウト・設定で1枚の UIImage に合成する。
    /// - Parameter longSide: 出力キャンバスの長辺ピクセル数
    static func render(
        images: [UIImage],
        layout: CollageLayout,
        spec: CanvasSpec,
        longSide: CGFloat = 2048
    ) -> UIImage {
        let canvasSize = spec.ratio.size(longSide: longSide)
        let rects = layout.photoRects(
            canvasSize: canvasSize,
            spec: spec,
            aspectRatios: images.map { $0.size.height > 0 ? $0.size.width / $0.size.height : 1 }
        )

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

            for (image, rect) in zip(images, rects) {
                image.draw(in: rect)
            }
        }
    }
}
