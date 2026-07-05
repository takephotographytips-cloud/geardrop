import CoreGraphics
import Foundation

/// 書き出しキャンバスの比率（2.2 仕様の5種）
enum CanvasRatio: String, CaseIterable, Identifiable, Codable {
    case square = "1:1"
    case fourFive = "4:5"
    case threeTwo = "3:2"
    case nineSixteen = "9:16"
    case fourThree = "4:3"

    var id: String { rawValue }

    /// 幅 ÷ 高さ
    var value: CGFloat {
        switch self {
        case .square: return 1.0
        case .fourFive: return 4.0 / 5.0
        case .threeTwo: return 3.0 / 2.0
        case .nineSixteen: return 9.0 / 16.0
        case .fourThree: return 4.0 / 3.0
        }
    }

    /// 長辺を指定してキャンバスのピクセルサイズを返す
    func size(longSide: CGFloat) -> CGSize {
        if value >= 1 {
            return CGSize(width: longSide, height: longSide / value)
        } else {
            return CGSize(width: longSide * value, height: longSide)
        }
    }
}

/// 余白（フレーム）の背景色。Phase 1 は白 / 黒 / オフホワイトの3色。
/// スポイト・カラーピッカーは Phase 2 で追加する。
enum BackgroundColorChoice: String, CaseIterable, Identifiable, Codable {
    case white
    case black
    case offWhite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .white: return "白"
        case .black: return "黒"
        case .offWhite: return "オフホワイト"
        }
    }

    /// sRGB 成分。オフホワイトは #F5F2ED（仕様 2.2）
    var rgba: (red: Double, green: Double, blue: Double, alpha: Double) {
        switch self {
        case .white: return (1.0, 1.0, 1.0, 1.0)
        case .black: return (0.0, 0.0, 0.0, 1.0)
        case .offWhite: return (0xF5 / 255.0, 0xF2 / 255.0, 0xED / 255.0, 1.0)
        }
    }
}

/// キャンバス設定（比率・余白・ガター・背景色）。
/// 余白とガターはキャンバス短辺に対する割合で保持し、解像度非依存にする。
struct CanvasSpec: Codable, Equatable {
    /// 出力比率
    var ratio: CanvasRatio = .fourFive
    /// 外周余白（短辺比 0〜0.15）
    var marginFraction: CGFloat = 0.05
    /// 写真同士の間隔（短辺比）。Phase 1 は固定デフォルト、スライダーは Phase 2。
    var gutterFraction: CGFloat = 0.02
    /// 背景色
    var background: BackgroundColorChoice = .offWhite

    static let marginRange: ClosedRange<CGFloat> = 0.0...0.15
}
