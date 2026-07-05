import CoreGraphics
import Foundation

/// レイアウト定義（仕様 2.3 の6種）とセル矩形計算。
///
/// 計算は2段階:
/// 1. `cellRects` — レイアウトが決めるセル（置き場所）の矩形
/// 2. `photoRects` — 各セルに写真をアスペクトフィットさせた最終矩形
///
/// 縦積み・横並びはセル自体を写真の比率で組む（withgar 型: 幅を揃え高さは写真に従う）
/// ため、cellRects と photoRects が一致する。写真のトリミングは一切行わない。
enum CollageLayout: String, CaseIterable, Identifiable, Codable {
    case verticalStack      // 縦積み（2〜6枚）
    case horizontalRow      // 横並び（2〜3枚）
    case mainPlusSub        // 大小: メイン＋サブ（2枚）
    case oneBigTwoSmall     // 1大＋2小（3枚）
    case grid2x2            // 2×2（4枚）
    case oneBigThreeSmall   // 1大＋3小（4枚）
    case grid               // グリッド（5〜6枚）

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verticalStack: return "縦積み"
        case .horizontalRow: return "横並び"
        case .mainPlusSub: return "大小"
        case .oneBigTwoSmall: return "1大＋2小"
        case .grid2x2: return "2×2"
        case .oneBigThreeSmall: return "1大＋3小"
        case .grid: return "グリッド"
        }
    }

    /// 選択枚数に応じたレイアウト候補（仕様 2.3 の表）。先頭がデフォルト。
    static func candidates(for photoCount: Int) -> [CollageLayout] {
        switch photoCount {
        case 2: return [.verticalStack, .horizontalRow, .mainPlusSub]
        case 3: return [.verticalStack, .oneBigTwoSmall, .horizontalRow]
        case 4: return [.grid2x2, .verticalStack, .oneBigThreeSmall]
        case 5, 6: return [.grid, .verticalStack]
        default: return []
        }
    }

    // MARK: - 矩形計算

    /// 各写真の最終描画矩形（セル内アスペクトフィット済み）を返す。
    /// - Parameters:
    ///   - canvasSize: キャンバス全体のサイズ
    ///   - spec: 余白・ガター設定（短辺比）
    ///   - aspectRatios: 各写真の幅÷高さ（選択順）
    func photoRects(canvasSize: CGSize, spec: CanvasSpec, aspectRatios: [CGFloat]) -> [CGRect] {
        let cells = cellRects(canvasSize: canvasSize, spec: spec, aspectRatios: aspectRatios)
        return zip(cells, aspectRatios).map { Self.aspectFit(ratio: $1, in: $0) }
    }

    /// レイアウトが決めるセル矩形を返す。
    func cellRects(canvasSize: CGSize, spec: CanvasSpec, aspectRatios: [CGFloat]) -> [CGRect] {
        let shortSide = min(canvasSize.width, canvasSize.height)
        let margin = spec.marginFraction * shortSide
        let gutter = spec.gutterFraction * shortSide
        let content = CGRect(origin: .zero, size: canvasSize)
            .insetBy(dx: margin, dy: margin)
        guard !aspectRatios.isEmpty, content.width > 0, content.height > 0 else { return [] }

        switch self {
        case .verticalStack:
            return Self.verticalStackRects(in: content, gutter: gutter, ratios: aspectRatios)
        case .horizontalRow:
            return Self.horizontalRowRects(in: content, gutter: gutter, ratios: aspectRatios)
        case .mainPlusSub:
            return Self.columnSplitRects(in: content, gutter: gutter, weights: [0.64, 0.36], rowsPerColumn: [1, 1])
        case .oneBigTwoSmall:
            return Self.columnSplitRects(in: content, gutter: gutter, weights: [0.62, 0.38], rowsPerColumn: [1, 2])
        case .grid2x2:
            return Self.gridRects(in: content, gutter: gutter, columns: 2, count: min(aspectRatios.count, 4))
        case .oneBigThreeSmall:
            return Self.bigTopThreeBottomRects(in: content, gutter: gutter)
        case .grid:
            return Self.gridRects(in: content, gutter: gutter, columns: 2, count: aspectRatios.count)
        }
    }

    /// 写真をトリミングせずセル内に収める（アスペクトフィット、中央寄せ）。
    static func aspectFit(ratio: CGFloat, in cell: CGRect) -> CGRect {
        guard ratio > 0 else { return cell }
        let cellRatio = cell.width / cell.height
        var size: CGSize
        if ratio > cellRatio {
            size = CGSize(width: cell.width, height: cell.width / ratio)
        } else {
            size = CGSize(width: cell.height * ratio, height: cell.height)
        }
        return CGRect(
            x: cell.midX - size.width / 2,
            y: cell.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    // MARK: - 個別レイアウト

    /// 縦積み: 全写真の幅を揃え、高さは各写真の比率に従う。
    /// コンテンツ領域に収まらない場合は幅を縮めて全体をフィットさせ、中央配置する。
    private static func verticalStackRects(in content: CGRect, gutter: CGFloat, ratios: [CGFloat]) -> [CGRect] {
        let inverseSum = ratios.reduce(CGFloat(0)) { $0 + 1 / $1 }
        let guttersTotal = gutter * CGFloat(ratios.count - 1)
        var width = content.width
        var totalHeight = width * inverseSum + guttersTotal
        if totalHeight > content.height {
            width = (content.height - guttersTotal) / inverseSum
            totalHeight = content.height
        }
        let x = content.midX - width / 2
        var y = content.midY - totalHeight / 2
        return ratios.map { ratio in
            let height = width / ratio
            let rect = CGRect(x: x, y: y, width: width, height: height)
            y += height + gutter
            return rect
        }
    }

    /// 横並び: 全写真の高さを揃え、幅は各写真の比率に従う。
    private static func horizontalRowRects(in content: CGRect, gutter: CGFloat, ratios: [CGFloat]) -> [CGRect] {
        let ratioSum = ratios.reduce(CGFloat(0), +)
        let guttersTotal = gutter * CGFloat(ratios.count - 1)
        var height = content.height
        var totalWidth = height * ratioSum + guttersTotal
        if totalWidth > content.width {
            height = (content.width - guttersTotal) / ratioSum
            totalWidth = content.width
        }
        var x = content.midX - totalWidth / 2
        let y = content.midY - height / 2
        return ratios.map { ratio in
            let width = height * ratio
            let rect = CGRect(x: x, y: y, width: width, height: height)
            x += width + gutter
            return rect
        }
    }

    /// 列分割: 各列を weights の比率で分け、列ごとに指定行数へ等分する。
    /// mainPlusSub（1列＋1列）/ oneBigTwoSmall（1列＋2行の列）で使用。
    private static func columnSplitRects(in content: CGRect, gutter: CGFloat, weights: [CGFloat], rowsPerColumn: [Int]) -> [CGRect] {
        let columnGuttersTotal = gutter * CGFloat(weights.count - 1)
        let availableWidth = content.width - columnGuttersTotal
        var rects: [CGRect] = []
        var x = content.minX
        for (index, weight) in weights.enumerated() {
            let columnWidth = availableWidth * weight
            let rows = rowsPerColumn[index]
            let rowGuttersTotal = gutter * CGFloat(rows - 1)
            let rowHeight = (content.height - rowGuttersTotal) / CGFloat(rows)
            var y = content.minY
            for _ in 0..<rows {
                rects.append(CGRect(x: x, y: y, width: columnWidth, height: rowHeight))
                y += rowHeight + gutter
            }
            x += columnWidth + gutter
        }
        return rects
    }

    /// 上に大セル1つ・下に小セル3つ（4枚用）。
    private static func bigTopThreeBottomRects(in content: CGRect, gutter: CGFloat) -> [CGRect] {
        let bigHeight = (content.height - gutter) * 0.66
        let smallHeight = content.height - gutter - bigHeight
        var rects = [CGRect(x: content.minX, y: content.minY, width: content.width, height: bigHeight)]
        let smallWidth = (content.width - gutter * 2) / 3
        let y = content.minY + bigHeight + gutter
        for i in 0..<3 {
            rects.append(CGRect(
                x: content.minX + CGFloat(i) * (smallWidth + gutter),
                y: y,
                width: smallWidth,
                height: smallHeight
            ))
        }
        return rects
    }

    /// 2列グリッド（4〜6枚用）。奇数枚のときは最終セルを行中央に寄せる。
    private static func gridRects(in content: CGRect, gutter: CGFloat, columns: Int, count: Int) -> [CGRect] {
        let rows = Int(ceil(Double(count) / Double(columns)))
        let cellWidth = (content.width - gutter * CGFloat(columns - 1)) / CGFloat(columns)
        let cellHeight = (content.height - gutter * CGFloat(rows - 1)) / CGFloat(rows)
        var rects: [CGRect] = []
        for index in 0..<count {
            let row = index / columns
            let column = index % columns
            let itemsInRow = min(columns, count - row * columns)
            let rowWidth = cellWidth * CGFloat(itemsInRow) + gutter * CGFloat(itemsInRow - 1)
            let rowStartX = content.midX - rowWidth / 2
            rects.append(CGRect(
                x: rowStartX + CGFloat(column) * (cellWidth + gutter),
                y: content.minY + CGFloat(row) * (cellHeight + gutter),
                width: cellWidth,
                height: cellHeight
            ))
        }
        return rects
    }
}
