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

/// 余白（フレーム）の背景色。sRGB 成分で保持する。
/// プリセット3色（白 / 黒 / オフホワイト #F5F2ED）に加え、
/// カラーピッカー（スポイト内蔵）で任意の色を設定できる（Phase 2）。
struct CanvasColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let white = CanvasColor(red: 1, green: 1, blue: 1)
    static let black = CanvasColor(red: 0, green: 0, blue: 0)
    /// オフホワイト #F5F2ED（仕様 2.2）
    static let offWhite = CanvasColor(red: 0xF5 / 255.0, green: 0xF2 / 255.0, blue: 0xED / 255.0)
}

/// キャンバス設定（比率・余白・ガター・背景色・フレーム）。
/// 余白とガターはキャンバス短辺に対する割合で保持し、解像度非依存にする。
struct CanvasSpec: Codable, Equatable {
    /// 出力比率
    var ratio: CanvasRatio
    /// 外周余白（短辺比 0〜0.15）
    var marginFraction: CGFloat
    /// 写真同士の間隔（短辺比 0〜0.10）
    var gutterFraction: CGFloat
    /// 背景色（フレームが backgroundOverride を持つ場合はそちらが優先）
    var background: CanvasColor
    /// デザインフレーム（Stack Pro）
    var frame: FrameStyle

    static let marginRange: ClosedRange<CGFloat> = 0.0...0.15
    static let gutterRange: ClosedRange<CGFloat> = 0.0...0.10

    init(
        ratio: CanvasRatio = .fourFive,
        marginFraction: CGFloat = 0.05,
        gutterFraction: CGFloat = 0.02,
        background: CanvasColor = .offWhite,
        frame: FrameStyle = .none
    ) {
        self.ratio = ratio
        self.marginFraction = marginFraction
        self.gutterFraction = gutterFraction
        self.background = background
        self.frame = frame
    }

    /// 旧バージョンで保存されたプリセット・セッション（frame キーなし）も読めるよう、
    /// 欠けているキーはデフォルト値で補う。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ratio = try container.decodeIfPresent(CanvasRatio.self, forKey: .ratio) ?? .fourFive
        marginFraction = try container.decodeIfPresent(CGFloat.self, forKey: .marginFraction) ?? 0.05
        gutterFraction = try container.decodeIfPresent(CGFloat.self, forKey: .gutterFraction) ?? 0.02
        background = try container.decodeIfPresent(CanvasColor.self, forKey: .background) ?? .offWhite
        frame = try container.decodeIfPresent(FrameStyle.self, forKey: .frame) ?? .none
    }
}
