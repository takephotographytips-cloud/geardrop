import CoreGraphics
import Foundation

/// デザインフレーム（Stack Pro）。
/// 画像アセットを使わず、すべてプログラム描画（矩形＋文字＋生成ノイズ）で表現する。
/// プレビュー(SwiftUI Canvas)と書き出し(CGContext)は同じ `decorationElements` を描くため、
/// 見た目が一致し、どの解像度でも劣化しない。
enum FrameStyle: String, Codable, CaseIterable, Identifiable {
    case none
    case film        // フィルムネガ: 黒地・パーフォレーション・銘柄文字
    case yellowFilm  // イエローネガ: 黒地・黄色い送り穴とコード数字
    case cinema      // シネマ: 黒地・両側の送り穴＋アンバーのコマ番号
    case print       // プリント: 紙白地・トンボとラベル

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .film: return "フィルム"
        case .yellowFilm: return "イエロー"
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
        case .yellowFilm: return CanvasColor(red: 0.04, green: 0.04, blue: 0.04)
        case .cinema: return CanvasColor(red: 0.03, green: 0.03, blue: 0.035)
        case .print: return CanvasColor(red: 0.957, green: 0.945, blue: 0.918)
        }
    }

    /// グレイン（粒状ノイズ）の強さ。0 でなし。フィルム系はオールド感を出すため薄くかける。
    var grainAlpha: CGFloat {
        switch self {
        case .none, .print: return 0
        case .film: return 0.08
        case .yellowFilm: return 0.09
        case .cinema: return 0.08
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
        let band: CGFloat
        switch self {
        case .none: return BandInsets()
        case .film: band = 0.10 * shortSide
        case .yellowFilm: band = 0.12 * shortSide
        case .cinema: band = 0.13 * shortSide
        case .print: band = 0.08 * shortSide
        }
        return vertical
            ? BandInsets(leading: band, trailing: band)
            : BandInsets(top: band, bottom: band)
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
        let context = BandContext(outer: outer, insets: insets, shortSide: shortSide, vertical: vertical)

        switch self {
        case .none: return []
        case .film: return filmElements(context, cells: cells)
        case .yellowFilm: return yellowFilmElements(context, cells: cells)
        case .cinema: return cinemaElements(context, cells: cells)
        case .print: return printElements(context, cells: cells)
        }
    }

    /// 帯の位置計算をまとめたヘルパー。
    /// 縦並びでは leading=左帯 / trailing=右帯、横並びでは leading=上帯 / trailing=下帯。
    private struct BandContext {
        let outer: CGRect
        let insets: BandInsets
        let shortSide: CGFloat
        let vertical: Bool

        /// 帯の中心線（クロス方向の座標）。offset は帯中心からのずれ（+が内側=写真側）。
        func leadingLine(offset: CGFloat = 0) -> CGFloat {
            vertical ? outer.minX + insets.leading / 2 + offset
                     : outer.minY + insets.top / 2 + offset
        }

        func trailingLine(offset: CGFloat = 0) -> CGFloat {
            vertical ? outer.maxX - insets.trailing / 2 - offset
                     : outer.maxY - insets.bottom / 2 - offset
        }

        /// 帯に沿った方向の範囲
        var start: CGFloat { vertical ? outer.minY : outer.minX }
        var end: CGFloat { vertical ? outer.maxY : outer.maxX }

        /// 帯に沿った位置 along・クロス位置 cross から点を作る
        func point(along: CGFloat, cross: CGFloat) -> CGPoint {
            vertical ? CGPoint(x: cross, y: along) : CGPoint(x: along, y: cross)
        }

        /// セルの帯方向の中心・始端
        func cellMid(_ cell: CGRect) -> CGFloat { vertical ? cell.midY : cell.midX }
        func cellStart(_ cell: CGRect) -> CGFloat { vertical ? cell.minY : cell.minX }
        func cellLength(_ cell: CGRect) -> CGFloat { vertical ? cell.height : cell.width }

        /// 縦並びなら回転して帯に沿わせる。横並びは水平のまま。
        func textRotation(mirrored: Bool = false) -> Double {
            vertical ? (mirrored ? 90 : -90) : 0
        }

        /// 穴のサイズ（縦並び基準の w×h を横並びでは転置する）
        func holeSize(_ width: CGFloat, _ height: CGFloat) -> CGSize {
            vertical ? CGSize(width: width, height: height)
                     : CGSize(width: height, height: width)
        }
    }

    // MARK: フィルムネガ

    private func filmElements(_ band: BandContext, cells: [CGRect]) -> [FrameElement] {
        let textColor = CanvasColor(red: 0.85, green: 0.83, blue: 0.78)
        let holeColor = CanvasColor(red: 0.93, green: 0.92, blue: 0.88)
        let s = band.shortSide
        var elements: [FrameElement] = []

        // 内側寄りの帯（右/下）: パーフォレーションの列
        elements += Self.holeStrip(
            band: band, crossLine: band.trailingLine(),
            holeSize: band.holeSize(0.030 * s, 0.022 * s),
            cornerRadius: 0.006 * s, pitch: 0.055 * s, color: holeColor
        )
        // 外側寄りの帯（左/上）: 各コマにフィルム銘柄とコマ番号
        for (index, cell) in cells.enumerated() {
            elements.append(.text(
                "STACK 400",
                center: band.point(along: band.cellMid(cell), cross: band.leadingLine()),
                height: 0.022 * s, rotationDegrees: band.textRotation(), color: textColor
            ))
            if band.cellLength(cell) > 0.24 * s {
                elements.append(.text(
                    String(format: "▸ %02d", index + 1),
                    center: band.point(along: band.cellStart(cell) + 0.05 * s, cross: band.leadingLine()),
                    height: 0.016 * s, rotationDegrees: band.textRotation(), color: textColor
                ))
            }
        }
        return elements
    }

    // MARK: イエローネガ

    private func yellowFilmElements(_ band: BandContext, cells: [CGRect]) -> [FrameElement] {
        let yellow = CanvasColor(red: 0.91, green: 0.83, blue: 0.28)
        let s = band.shortSide
        var elements: [FrameElement] = []

        // 両側の帯: 内側寄りに黄色い送り穴の列
        let holeSize = band.holeSize(0.042 * s, 0.032 * s)
        for crossLine in [band.leadingLine(offset: 0.026 * s), band.trailingLine(offset: 0.026 * s)] {
            elements += Self.holeStrip(
                band: band, crossLine: crossLine,
                holeSize: holeSize,
                cornerRadius: 0.010 * s, pitch: 0.068 * s, color: yellow
            )
        }
        // 外側寄りにコード数字（実フィルムの縁印字風）
        let length = band.end - band.start
        let leadingTexts: [(String, CGFloat)] = [("73920", 0.12), ("17", 0.46), ("▸ 17", 0.82)]
        let trailingTexts: [(String, CGFloat)] = [("STACK 400", 0.18), ("17", 0.55), ("17A", 0.88)]
        for (string, fraction) in leadingTexts {
            elements.append(.text(
                string,
                center: band.point(along: band.start + length * fraction, cross: band.leadingLine(offset: -0.033 * s)),
                height: 0.020 * s, rotationDegrees: band.textRotation(), color: yellow
            ))
        }
        for (string, fraction) in trailingTexts {
            elements.append(.text(
                string,
                center: band.point(along: band.start + length * fraction, cross: band.trailingLine(offset: -0.033 * s)),
                height: 0.020 * s, rotationDegrees: band.textRotation(mirrored: true), color: yellow
            ))
        }
        return elements
    }

    // MARK: シネマ

    private func cinemaElements(_ band: BandContext, cells: [CGRect]) -> [FrameElement] {
        let holeColor = CanvasColor(red: 0.94, green: 0.93, blue: 0.89)
        let amber = CanvasColor(red: 0.85, green: 0.63, blue: 0.28)
        let s = band.shortSide
        let holeSize = band.holeSize(0.050 * s, 0.042 * s)
        let cornerRadius = 0.011 * s
        var elements: [FrameElement] = []

        for (index, cell) in cells.enumerated() {
            // 両側にコマごとの送り穴（35mm シネフィルム風）
            for fraction in [0.2, 0.5, 0.8] as [CGFloat] {
                let along = band.cellStart(cell) + band.cellLength(cell) * fraction
                for crossLine in [band.leadingLine(offset: 0.022 * s), band.trailingLine(offset: 0.022 * s)] {
                    let center = band.point(along: along, cross: crossLine)
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
            // アンバーのコマ番号（縁印字風）: 左/上帯に番号、右/下帯に送りマーカー
            elements.append(.text(
                "\(index + 3)",
                center: band.point(
                    along: band.cellStart(cell) + band.cellLength(cell) * 0.35,
                    cross: band.leadingLine(offset: -0.043 * s)
                ),
                height: 0.022 * s, rotationDegrees: band.textRotation(), color: amber
            ))
            elements.append(.text(
                "▷ \(index + 3)A",
                center: band.point(
                    along: band.cellStart(cell) + band.cellLength(cell) * 0.65,
                    cross: band.trailingLine(offset: -0.043 * s)
                ),
                height: 0.017 * s, rotationDegrees: band.textRotation(mirrored: true), color: amber
            ))
        }
        return elements
    }

    // MARK: プリント

    private func printElements(_ band: BandContext, cells: [CGRect]) -> [FrameElement] {
        let ink = CanvasColor(red: 0.29, green: 0.28, blue: 0.26)
        let s = band.shortSide
        var elements: [FrameElement] = []

        for (index, cell) in cells.enumerated() {
            let label = index.isMultiple(of: 2) ? "STACK 001" : "STACK STORY"
            elements.append(.text(
                label,
                center: band.point(along: band.cellMid(cell), cross: band.leadingLine()),
                height: 0.017 * s, rotationDegrees: band.textRotation(), color: ink
            ))
            elements.append(.text(
                "001",
                center: band.point(along: band.cellMid(cell), cross: band.trailingLine()),
                height: 0.015 * s, rotationDegrees: band.textRotation(mirrored: true), color: ink
            ))
            elements.append(.text(
                "▲",
                center: band.point(along: band.cellStart(cell) + 0.03 * s, cross: band.trailingLine()),
                height: 0.013 * s, rotationDegrees: 0, color: ink
            ))
        }
        return elements
    }

    // MARK: 共通部品

    /// 帯に沿って等間隔で並ぶ穴の列。crossLine は穴中心のクロス方向座標。
    private static func holeStrip(
        band: BandContext,
        crossLine: CGFloat,
        holeSize: CGSize,
        cornerRadius: CGFloat,
        pitch: CGFloat,
        color: CanvasColor
    ) -> [FrameElement] {
        let length = band.end - band.start
        guard pitch > 0, length > pitch else { return [] }
        let count = Int(length / pitch)
        let startAlong = (band.start + band.end) / 2 - CGFloat(count - 1) / 2 * pitch
        return (0..<count).map { index in
            let center = band.point(along: startAlong + CGFloat(index) * pitch, cross: crossLine)
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
