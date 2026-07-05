import CoreGraphics
import Foundation

/// セル内の写真の表示状態。セルごとに完全に独立して保持し、他のセルへ影響しない。
///
/// offset はセルの幅・高さに対する正規化値で保持する。これによりレイアウト変更で
/// セルサイズが変わっても、写真の相対位置とズーム率を可能な限り維持できる
/// （描画時に新しいセルサイズで再計算・クランプされる）。
struct CellTransform: Codable, Equatable {
    /// カバー表示（セルにぴったり収まる状態）を 1 とする拡大率
    var scale: CGFloat = 1
    /// セル幅・高さに対する正規化オフセット（中心からのずれ）
    var offset: CGSize = .zero
    /// 回転角（度）。将来対応を見据えて保持のみ行い、描画にはまだ適用しない。
    var rotationDegrees: Double = 0
}

/// セル内のカバー配置（BoxFit.cover 相当）＋変形の矩形計算。
/// プレビュー(SwiftUI)と書き出し(CGContext)の両方がここを通ることで描画結果を一致させる。
enum CellGeometry {

    /// ズーム率の許容範囲。1 未満だとセルに余白（背景）が見えてしまうため下限は 1。
    static let scaleRange: ClosedRange<CGFloat> = 1.0...5.0

    /// 変形適用後の写真描画矩形を返す。矩形は常にセル全体を覆う
    /// （はみ出し部分は呼び出し側でセル矩形にクリップして描画する）。
    static func imageRect(imageRatio: CGFloat, cell: CGRect, transform: CellTransform) -> CGRect {
        guard imageRatio > 0, cell.width > 0, cell.height > 0 else { return cell }
        let clampedTransform = clamped(transform, imageRatio: imageRatio, cell: cell)
        let size = coverSize(imageRatio: imageRatio, cell: cell, scale: clampedTransform.scale)
        let center = CGPoint(
            x: cell.midX + clampedTransform.offset.width * cell.width,
            y: cell.midY + clampedTransform.offset.height * cell.height
        )
        return CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// セルを完全に覆う最小サイズ（カバーフィット）× 拡大率。
    static func coverSize(imageRatio: CGFloat, cell: CGRect, scale: CGFloat) -> CGSize {
        let cellRatio = cell.width / cell.height
        let base: CGSize
        if imageRatio > cellRatio {
            // 写真がセルより横長 → 高さを合わせ、横がはみ出す
            base = CGSize(width: cell.height * imageRatio, height: cell.height)
        } else {
            // 写真がセルより縦長 → 幅を合わせ、縦がはみ出す
            base = CGSize(width: cell.width, height: cell.width / imageRatio)
        }
        return CGSize(width: base.width * scale, height: base.height * scale)
    }

    /// scale と offset を「セルの外（背景）が見えない」範囲にクランプする。
    static func clamped(_ transform: CellTransform, imageRatio: CGFloat, cell: CGRect) -> CellTransform {
        var result = transform
        result.scale = min(max(result.scale, scaleRange.lowerBound), scaleRange.upperBound)
        guard imageRatio > 0, cell.width > 0, cell.height > 0 else { return result }
        let size = coverSize(imageRatio: imageRatio, cell: cell, scale: result.scale)
        let maxOffsetX = (size.width - cell.width) / 2 / cell.width
        let maxOffsetY = (size.height - cell.height) / 2 / cell.height
        result.offset.width = min(max(result.offset.width, -maxOffsetX), maxOffsetX)
        result.offset.height = min(max(result.offset.height, -maxOffsetY), maxOffsetY)
        return result
    }
}
