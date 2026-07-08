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
                let rotation = CellTransform.normalizedDegrees(transform.rotationDegrees)
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.clip(to: cell)
                if rotation != 0 {
                    // 矩形中心を軸に回転して描画（プレビューの rotationEffect と一致）
                    cgContext.translateBy(x: imageRect.midX, y: imageRect.midY)
                    cgContext.rotate(by: CGFloat(rotation) * .pi / 180)
                    image.draw(in: CGRect(
                        x: -imageRect.width / 2,
                        y: -imageRect.height / 2,
                        width: imageRect.width,
                        height: imageRect.height
                    ))
                } else {
                    image.draw(in: imageRect)
                }
                cgContext.restoreGState()
            }

            FrameElementRenderer.draw(
                spec.frame.decorationElements(canvasSize: canvasSize, spec: spec, layout: layout, cells: cells),
                in: context.cgContext
            )
            FrameElementRenderer.drawGrain(
                alpha: spec.frame.grainAlpha,
                canvasSize: canvasSize,
                in: context.cgContext
            )
        }
    }
}

/// フィルム系フレーム用のグレイン（粒状ノイズ）テクスチャ。
/// シード固定の擬似乱数で生成するため、常に同じ模様＝プレビューと書き出しが一致する。
enum GrainTexture {
    /// タイルの1辺（ピクセル）
    static let tilePixelSize = 256

    static let shared: UIImage = generate()

    private static func generate() -> UIImage {
        let size = tilePixelSize
        // SplitMix64 による決定的なノイズ
        var state: UInt64 = 0x5EED_1234_ABCD_9876
        func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        var pixels = [UInt8](repeating: 128, count: size * size)
        for index in pixels.indices {
            pixels[index] = UInt8(truncatingIfNeeded: next())
        }
        let image: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            return context.makeImage()
        }
        guard let image else { return UIImage() }
        return UIImage(cgImage: image)
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

    /// グレインをキャンバス全体にオーバーレイ合成する（alpha 0 なら何もしない）。
    /// タイルの表示サイズは短辺の 1/8 に固定し、解像度が違っても粒の相対サイズを揃える。
    static func drawGrain(alpha: CGFloat, canvasSize: CGSize, in context: CGContext) {
        guard alpha > 0, let grain = GrainTexture.shared.cgImage else { return }
        let shortSide = min(canvasSize.width, canvasSize.height)
        guard shortSide > 0 else { return }
        let tileDisplaySize = shortSide / 8
        let scale = tileDisplaySize / CGFloat(GrainTexture.tilePixelSize)

        context.saveGState()
        context.clip(to: CGRect(origin: .zero, size: canvasSize))
        context.setAlpha(alpha)
        context.setBlendMode(.overlay)
        context.scaleBy(x: scale, y: scale)
        context.draw(
            grain,
            in: CGRect(x: 0, y: 0, width: GrainTexture.tilePixelSize, height: GrainTexture.tilePixelSize),
            byTiling: true
        )
        context.restoreGState()
    }

    private static func cgColor(_ color: CanvasColor) -> CGColor {
        CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}
