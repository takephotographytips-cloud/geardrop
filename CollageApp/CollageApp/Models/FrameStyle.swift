import CoreGraphics
import Foundation

/// デザインフレーム（Stack Pro）。
/// 画像アセットを使わず、すべてプログラム描画（矩形＋文字）で表現する。
/// プレビュー(SwiftUI Canvas)と書き出し(CGContext)は同じ `decorationElements` を描くため、
/// 見た目が一致し、どの解像度でも劣化しない。
enum FrameStyle: String, Codable, CaseIterable, Identifiable {
    case none
    case film       // フィルムネガ: 黒地・パーフォレーション・銘柄文字
    case cinema     // 映画フィルム: 黒地・大きな送り穴
    case print      // 紙焼き: 紙白地・トンボとラベル

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .film: return "フィルム"
        case .cinema: return "シネマ"
        case .print: return "プリント"
        }
    }

    /// Pro 限定か（なし以外はすべて Pro）
    var isPro: Bool { self != .none }

    /// フレームが強制する背景色。nil なら通常の背景色設定を使う。
    var backgroundOverride: CanvasColor? {
        switch self {
        case .none: return nil
        case .film: return CanvasColor(red: 0.05, green: 0.05, blue: 0.055)
        case .cinema: return CanvasColor(red: 0.03, green: 0.03, blue: 0.035)
        case .print: return CanvasColor(red: 0.957, green: 0.945, blue: 0.918)
        }
    }

    /// フレーム帯の太さ（コンテンツ領域の内側に追加する余白）。
    /// 縦並びは左右、横並びは上下に帯を取る。
    struct BandInsets: Equatable {
        var leading: CGFloat = 0
        var trailing: CGFloat = 0
        var top: CGFloat = 0
        var bottom: CGFloat = 0
    }

    func bandInsets(layout: CollageLayout, shortSide: CGFloat) -> BandInsets {
        let vertical = (layout == .verticalStack)
        switch self {
        case .none:
            return BandInsets()
        case .film:
            let band = 0.10 * shortSide
            return vertical
                ? BandInsets(leading: band, trailing: band)
                : BandInsets(top: band, bottom: band)
        case .cinema:
            let band = 0.16 * shortSide
            return vertical
                ? BandInsets(leading: band)
                : BandInsets(top: band)
        case .print:
            let band = 0.08 * shortSide
            return vertical
                ? BandInsets(leading: band, trailing: band)
                : BandInsets(top: band, bottom: band)
        }
    }

    // MARK: - 装飾要素の生成

    /// フレームの装飾（穴・文字）を座標付きで返す。cells はフレーム帯適用済みのセル矩形。
    func decorationElements(
        canvasSize: CGSize,
        spec: CanvasSpec,
        layout: CollageLayout,
        cells: [CGRect]
    ) -> [FrameElement] {
        guard self != .none, !cells.isEmpty else { return [] }
        let shortSide = min(canvasSize.width, canvasSize.height)
        let margin = spec.marginFraction * shortSide
        let outer = CGRect(origin: .zero, size: canvasSize).insetBy(dx: margin, dy: margin)
        let insets = bandInsets(layout: layout, shortSide: shortSide)
        let vertical = (layout == .verticalStack)

        switch self {
        case .none:
            return []
        case .film:
            return filmElements(outer: outer, insets: insets, cells: cells, shortSide: shortSide, vertical: vertical)
        case .cinema:
            return cinemaElements(outer: outer, insets: insets, cells: cells, shortSide: shortSide, vertical: vertical)
        case .print:
            return printElements(outer: outer, insets: insets, cells: cells, shortSide: shortSide, vertical: vertical)
        }
    }

    // MARK: フィルムネガ

    private func filmElements(
        outer: CGRect, insets: BandInsets, cells: [CGRect], shortSide: CGFloat, vertical: Bool
    ) -> [FrameElement] {
        let textColor = CanvasColor(red: 0.85, green: 0.83, blue: 0.78)
        let holeColor = CanvasColor(red: 0.93, green: 0.92, blue: 0.88)
        var elements: [FrameElement] = []

        if vertical {
            let leadingBand = CGRect(x: outer.minX, y: outer.minY, width: insets.leading, height: outer.height)
            let trailingBand = CGRect(x: outer.maxX - insets.trailing, y: outer.minY, width: insets.trailing, height: outer.height)
            // 右帯: パーフォレーション（送り穴）の列
            elements += Self.holeColumn(
                in: trailingBand,
                holeSize: CGSize(width: 0.030 * shortSide, height: 0.022 * shortSide),
                cornerRadius: 0.006 * shortSide,
                pitch: 0.055 * shortSide,
                color: holeColor,
                vertical: true
            )
            // 左帯: 各コマにフィルム銘柄とコマ番号
            for (index, cell) in cells.enumerated() {
                elements.append(.text(
                    "STACK 400",
                    center: CGPoint(x: leadingBand.midX, y: cell.midY),
                    height: 0.022 * shortSide, rotationDegrees: -90, color: textColor
                ))
                if cell.height > 0.24 * shortSide {
                    elements.append(.text(
                        String(format: "▸ %02d", index + 1),
                        center: CGPoint(x: leadingBand.midX, y: cell.minY + 0.05 * shortSide),
                        height: 0.016 * shortSide, rotationDegrees: -90, color: textColor
                    ))
                }
            }
        } else {
            let topBand = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: insets.top)
            let bottomBand = CGRect(x: outer.minX, y: outer.maxY - insets.bottom, width: outer.width, height: insets.bottom)
            elements += Self.holeColumn(
                in: bottomBand,
                holeSize: CGSize(width: 0.022 * shortSide, height: 0.030 * shortSide),
                cornerRadius: 0.006 * shortSide,
                pitch: 0.055 * shortSide,
                color: holeColor,
                vertical: false
            )
            for (index, cell) in cells.enumerated() {
                elements.append(.text(
                    "STACK 400",
                    center: CGPoint(x: cell.midX, y: topBand.midY),
                    height: 0.022 * shortSide, rotationDegrees: 0, color: textColor
                ))
                if cell.width > 0.24 * shortSide {
                    elements.append(.text(
                        String(format: "▸ %02d", index + 1),
                        center: CGPoint(x: cell.minX + 0.05 * shortSide, y: topBand.midY),
                        height: 0.016 * shortSide, rotationDegrees: 0, color: textColor
                    ))
                }
            }
        }
        return elements
    }

    // MARK: シネマ

    private func cinemaElements(
        outer: CGRect, insets: BandInsets, cells: [CGRect], shortSide: CGFloat, vertical: Bool
    ) -> [FrameElement] {
        let holeColor = CanvasColor(red: 0.94, green: 0.93, blue: 0.89)
        let holeSize = vertical
            ? CGSize(width: 0.072 * shortSide, height: 0.052 * shortSide)
            : CGSize(width: 0.052 * shortSide, height: 0.072 * shortSide)
        let cornerRadius = 0.014 * shortSide
        var elements: [FrameElement] = []

        for cell in cells {
            for fraction in [0.22, 0.5, 0.78] as [CGFloat] {
                let center: CGPoint
                if vertical {
                    let band = CGRect(x: outer.minX, y: outer.minY, width: insets.leading, height: outer.height)
                    center = CGPoint(x: band.midX, y: cell.minY + cell.height * fraction)
                } else {
                    let band = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: insets.top)
                    center = CGPoint(x: cell.minX + cell.width * fraction, y: band.midY)
                }
                elements.append(.roundedRect(
                    rect: CGRect(
                        x: center.x - holeSize.width / 2,
                        y: center.y - holeSize.height / 2,
                        width: holeSize.width,
                        height: holeSize.height
                    ),
                    cornerRadius: cornerRadius,
                    color: holeColor
                ))
            }
        }
        return elements
    }

    // MARK: プリント

    private func printElements(
        outer: CGRect, insets: BandInsets, cells: [CGRect], shortSide: CGFloat, vertical: Bool
    ) -> [FrameElement] {
        let ink = CanvasColor(red: 0.29, green: 0.28, blue: 0.26)
        var elements: [FrameElement] = []

        for (index, cell) in cells.enumerated() {
            let label = index.isMultiple(of: 2) ? "STACK 001" : "STACK STORY"
            if vertical {
                let leadingBand = CGRect(x: outer.minX, y: outer.minY, width: insets.leading, height: outer.height)
                let trailingBand = CGRect(x: outer.maxX - insets.trailing, y: outer.minY, width: insets.trailing, height: outer.height)
                elements.append(.text(
                    label,
                    center: CGPoint(x: leadingBand.midX, y: cell.midY),
                    height: 0.017 * shortSide, rotationDegrees: -90, color: ink
                ))
                elements.append(.text(
                    "001",
                    center: CGPoint(x: trailingBand.midX, y: cell.midY),
                    height: 0.015 * shortSide, rotationDegrees: 90, color: ink
                ))
                elements.append(.text(
                    "▲",
                    center: CGPoint(x: trailingBand.midX, y: cell.minY + 0.03 * shortSide),
                    height: 0.013 * shortSide, rotationDegrees: 0, color: ink
                ))
            } else {
                let topBand = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: insets.top)
                let bottomBand = CGRect(x: outer.minX, y: outer.maxY - insets.bottom, width: outer.width, height: insets.bottom)
                elements.append(.text(
                    label,
                    center: CGPoint(x: cell.midX, y: topBand.midY),
                    height: 0.017 * shortSide, rotationDegrees: 0, color: ink
                ))
                elements.append(.text(
                    "001",
                    center: CGPoint(x: cell.midX, y: bottomBand.midY),
                    height: 0.015 * shortSide, rotationDegrees: 0, color: ink
                ))
                elements.append(.text(
                    "▲",
                    center: CGPoint(x: cell.minX + 0.03 * shortSide, y: bottomBand.midY),
                    height: 0.013 * shortSide, rotationDegrees: 0, color: ink
                ))
            }
        }
        return elements
    }

    // MARK: 共通部品

    /// 帯の中央に等間隔で並ぶ穴の列（vertical: 縦方向に並べる）
    private static func holeColumn(
        in band: CGRect,
        holeSize: CGSize,
        cornerRadius: CGFloat,
        pitch: CGFloat,
        color: CanvasColor,
        vertical: Bool
    ) -> [FrameElement] {
        let length = vertical ? band.height : band.width
        guard pitch > 0, length > pitch else { return [] }
        let count = Int(length / pitch)
        let start = (vertical ? band.midY : band.midX) - CGFloat(count - 1) / 2 * pitch
        return (0..<count).map { index in
            let position = start + CGFloat(index) * pitch
            let center = vertical
                ? CGPoint(x: band.midX, y: position)
                : CGPoint(x: position, y: band.midY)
            return .roundedRect(
                rect: CGRect(
                    x: center.x - holeSize.width / 2,
                    y: center.y - holeSize.height / 2,
                    width: holeSize.width,
                    height: holeSize.height
                ),
                cornerRadius: cornerRadius,
                color: color
            )
        }
    }
}

/// フレーム装飾のプリミティブ。プレビューと書き出しの両方がこれを描画する。
enum FrameElement: Equatable {
    case roundedRect(rect: CGRect, cornerRadius: CGFloat, color: CanvasColor)
    case text(String, center: CGPoint, height: CGFloat, rotationDegrees: Double, color: CanvasColor)
}
