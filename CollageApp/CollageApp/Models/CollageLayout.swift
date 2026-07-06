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
    case centerFocus        // センターフォーカス: 雑誌風。中央が主役・左右は端まで(Pro)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verticalStack: return "縦並び"
        case .horizontalRow: return "横並び"
        case .centerFocus: return "センター"
        }
    }

    var symbolName: String {
        switch self {
        case .verticalStack: return "rectangle.split.1x2"
        case .horizontalRow: return "rectangle.split.2x1"
        case .centerFocus: return "rectangle.split.3x1"
        }
    }

    /// Pro 限定レイアウトか（Stack Pro で解放）
    var isPro: Bool { self == .centerFocus }

    /// 選択枚数に応じたレイアウト候補。先頭がデフォルト。
    /// 1枚のときは縦・横が同一（コンテンツ領域全体の1セル）になるため縦のみ出す。
    static func candidates(for photoCount: Int) -> [CollageLayout] {
        switch photoCount {
        case 1: return [.verticalStack, .centerFocus]
        case 2...6: return [.verticalStack, .horizontalRow, .centerFocus]
        default: return []
        }
    }

    /// セル矩形を返す。
    ///
    /// - 縦並び: セル高さ = (利用可能高さ − ガター合計) ÷ 枚数、幅は共通
    /// - 横並び: セル幅 = (利用可能幅 − ガター合計) ÷ 枚数、高さは共通
    /// - センターフォーカス: 横一列・枚数別の重み配分。左右はキャンバス端まで
    ///   （横マージンなし）、余白は写真間（innerSpacing = gutter）のみ。
    ///   上下は margin（TopPadding / BottomPadding）を適用
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
        case .centerFocus:
            // 左右マージンなし: x=0 からキャンバス右端まで使う。
            // 縦方向は content（margin + フレーム帯適用済み）に従う。
            let usableWidth = canvasSize.width - guttersTotal
            guard usableWidth > 0 else { return [] }
            let weights = Self.centerFocusWeights(for: count)
            var x: CGFloat = 0
            return weights.map { weight in
                let width = usableWidth * weight
                let rect = CGRect(x: x, y: content.minY, width: width, height: content.height)
                x += width + gutter
                return rect
            }
        }
    }

    /// センターフォーカスの枚数別の幅配分（合計1）。中央（または中央2枚）が主役。
    static func centerFocusWeights(for count: Int) -> [CGFloat] {
        switch count {
        case 1: return [1.0]
        case 2: return [0.5, 0.5]
        case 3: return [0.22, 0.56, 0.22]
        case 4: return [0.16, 0.34, 0.34, 0.16]
        case 5: return [0.10, 0.16, 0.48, 0.16, 0.10]
        case 6: return [0.10, 0.14, 0.26, 0.26, 0.14, 0.10]
        default: return Array(repeating: 1.0 / CGFloat(max(count, 1)), count: max(count, 1))
        }
    }
}
