import UIKit

/// プレビュー解像度のコラージュ合成（仕様 3.2: 表示用は長辺2048px）。
/// 書き出しは ExportRenderer（フル解像度）が担い、こちらはサムネイル生成等に使う。
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
            let background = spec.frame.backgroundOverride ?? spec.background
            UIColor(
                red: background.red,
                green: background.green,
                blue: background.blue,
                alpha: 1
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

            FrameElementRenderer.draw(
                spec.frame.decorationElements(canvasSize: canvasSize, spec: spec, layout: layout, cells: cells),
                in: context.cgContext
            )
        }
    }
}

/// フレーム装飾（FrameElement）を CGContext に描く。
/// 左上原点（UIKit 向き）のコンテキストを前提とする。
enum FrameElementRenderer {

    static func draw(_ elements: [FrameElement], in context: CGContext) {
        guard !elements.isEmpty else { return }
        for element in elements {
            switch element {
            case .roundedRect(let rect, let cornerRadius, let color):
                context.setFillColor(cgColor(color))
                context.addPath(CGPath(
                    roundedRect: rect,
                    cornerWidth: min(cornerRadius, rect.width / 2),
                    cornerHeight: min(cornerRadius, rect.height / 2),
                    transform: nil
                ))
                context.fillPath()
            case .text(let string, let center, let height, let rotationDegrees, let color):
                context.saveGState()
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: rotationDegrees * .pi / 180)
                UIGraphicsPushContext(context)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: height, weight: .semibold),
                    .foregroundColor: UIColor(
                        red: color.red,
                        green: color.green,
                        blue: color.blue,
                        alpha: 1
                    ),
                ]
                let attributed = NSAttributedString(string: string, attributes: attributes)
                let size = attributed.size()
                attributed.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
                UIGraphicsPopContext()
                context.restoreGState()
            }
        }
    }

    private static func cgColor(_ color: CanvasColor) -> CGColor {
        CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}
