import CoreGraphics
import Foundation

/// レイアウト定義とセル矩形計算（仕様変更 v1.1: Instagram / Canva 型）。
///
/// レイアウトは縦方向分割・横方向分割の2パターン。セル（枠）は枚数で均等分割した
/// 固定サイズで、写真はセルいっぱいに表示（カバーフィット）し、はみ出しはトリミング
/// される。セル内での写真の移動・拡大縮小は `CellTransform` + `CellGeometry` が担う。
enum CollageLayout: String, CaseIterable, Identifiable, Codable {
    case verticalStack      // 縦並び: 高さ均等・幅共通
    case horizontalRow      // 横並び: 幅均等・高さ共通

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verticalStack: return "縦並び"
        case .horizontalRow: return "横並び"
        }
    }

    var symbolName: String {
        switch self {
        case .verticalStack: return "rectangle.split.1x2"
        case .horizontalRow: return "rectangle.split.2x1"
        }
    }

    /// 選択枚数に応じたレイアウト候補。先頭がデフォルト。
    /// 1枚のときは縦・横とも同一（コンテンツ領域全体の1セル）になる。
    static func candidates(for photoCount: Int) -> [CollageLayout] {
        guard (1...6).contains(photoCount) else { return [] }
        return [.verticalStack, .horizontalRow]
    }

    /// 枚数で均等分割したセル矩形を返す。
    ///
    /// - 縦並び: セル高さ = (利用可能高さ − ガター合計) ÷ 枚数、幅は共通
    /// - 横並び: セル幅 = (利用可能幅 − ガター合計) ÷ 枚数、高さは共通
    ///
    /// 余白（margin）とガターはキャンバス短辺に対する割合（`CanvasSpec`）。
    func cellRects(canvasSize: CGSize, spec: CanvasSpec, count: Int) -> [CGRect] {
        let shortSide = min(canvasSize.width, canvasSize.height)
        let margin = spec.marginFraction * shortSide
        let gutter = spec.gutterFraction * shortSide
        var content = CGRect(origin: .zero, size: canvasSize)
            .insetBy(dx: margin, dy: margin)
        // デザインフレームの帯ぶんをさらに内側へ
        let band = spec.frame.bandInsets(layout: self, shortSide: shortSide)
        content = CGRect(
            x: content.minX + band.leading,
            y: content.minY + band.top,
            width: content.width - band.leading - band.trailing,
            height: content.height - band.top - band.bottom
        )
        guard count > 0, content.width > 0, content.height > 0 else { return [] }

        let guttersTotal = gutter * CGFloat(count - 1)
        switch self {
        case .verticalStack:
            let cellHeight = (content.height - guttersTotal) / CGFloat(count)
            return (0..<count).map { index in
                CGRect(
                    x: content.minX,
                    y: content.minY + CGFloat(index) * (cellHeight + gutter),
                    width: content.width,
                    height: cellHeight
                )
            }
        case .horizontalRow:
            let cellWidth = (content.width - guttersTotal) / CGFloat(count)
            return (0..<count).map { index in
                CGRect(
                    x: content.minX + CGFloat(index) * (cellWidth + gutter),
                    y: content.minY,
                    width: cellWidth,
                    height: content.height
                )
            }
        }
    }
}
