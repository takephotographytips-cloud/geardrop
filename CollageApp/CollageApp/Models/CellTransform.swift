import CoreGraphics
import Foundation

/// セル内の写真の表示状態。セルごとに完全独立（他セルへ影響しない）。
///
/// offset はセル寸法に対する正規化値で保持する。これによりレイアウト変更で
/// セルサイズが変わっても、写真の相対位置とズーム率を可能な限り維持できる
/// （描画時に新しいセルサイズで再計算・クランプされる）。
struct CellTransform: Codable, Equatable {
    /// カバー表示（セルにぴったり収まる状態）を 1 とする拡大率
    var scale: CGFloat = 1
    /// セル幅・高さに対する正規化オフセット（中心からのずれ）
    var offset: CGSize = .zero
    /// 回転角（度）。90°単位の回転＋±15°の水平微調整の合成値（Stack Pro）。
    /// 正の値は時計回り。
    var rotationDegrees: Double = 0

    /// 90°単位の成分（水平微調整を除いた回転）
    var quarterTurnsDegrees: Double {
        (rotationDegrees / 90).rounded() * 90
    }

    /// 水平微調整の成分（±45°未満。UI では ±15°に制限）
    var fineAngleDegrees: Double {
        rotationDegrees - quarterTurnsDegrees
    }

    /// (-180, 180] に正規化した角度を返す
    static func normalizedDegrees(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value <= -180 { value += 360 }
        return value
    }
}

/// セル内のカバー配置（BoxFit.cover 相当）＋変形（ズーム・移動・回転）の矩形計算。
/// プレビュー(SwiftUI)と書き出し(CGContext)の両方がここを通ることで描画結果を一致させる。
enum CellGeometry {

    /// ズーム率の許容範囲。1 未満だとセルに余白（背景）が見えてしまうため下限は 1。
    static let scaleRange: ClosedRange<CGFloat> = 1.0...5.0
    /// 水平微調整の許容範囲（度）
    static let fineAngleRange: ClosedRange<Double> = -15.0...15.0

    /// 変形適用後の写真描画矩形（回転前の外接矩形）を返す。
    /// 呼び出し側は矩形の中心を軸に `transform.rotationDegrees` だけ回転させて描画する。
    /// 矩形サイズは回転を考慮した「セルを完全に覆う最小サイズ×拡大率」。
    static func imageRect(imageRatio: CGFloat, cell: CGRect, transform: CellTransform) -> CGRect {
        guard imageRatio > 0, cell.width > 0, cell.height > 0 else { return cell }
        let clampedTransform = clamped(transform, imageRatio: imageRatio, cell: cell)
        let size = coverSize(
            imageRatio: imageRatio,
            cell: cell,
            scale: clampedTransform.scale,
            rotationDegrees: clampedTransform.rotationDegrees
        )
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

    /// 角度 θ で回転した写真がセルを完全に覆う最小サイズ（×拡大率）。
    /// 回転した写真座標系でのセルの外接幅/高さ:
    ///   needW = W|cosθ| + H|sinθ| / needH = W|sinθ| + H|cosθ|
    /// θ = 0 のときは従来のカバーフィットと一致する。
    static func coverSize(
        imageRatio: CGFloat,
        cell: CGRect,
        scale: CGFloat,
        rotationDegrees: Double = 0
    ) -> CGSize {
        let theta = CGFloat(rotationDegrees) * .pi / 180
        let c = abs(cos(theta))
        let s = abs(sin(theta))
        let neededWidth = cell.width * c + cell.height * s
        let neededHeight = cell.width * s + cell.height * c
        let baseHeight = max(neededWidth / imageRatio, neededHeight)
        return CGSize(width: baseHeight * imageRatio * scale, height: baseHeight * scale)
    }

    /// scale とオフセットを「セルの外（背景）が見えない」範囲にクランプする。
    /// 回転がある場合は写真のローカル軸に射影してからクランプする（数学的に厳密）。
    static func clamped(_ transform: CellTransform, imageRatio: CGFloat, cell: CGRect) -> CellTransform {
        var result = transform
        result.scale = min(max(result.scale, scaleRange.lowerBound), scaleRange.upperBound)
        result.rotationDegrees = CellTransform.normalizedDegrees(result.rotationDegrees)
        guard imageRatio > 0, cell.width > 0, cell.height > 0 else { return result }

        let size = coverSize(
            imageRatio: imageRatio,
            cell: cell,
            scale: result.scale,
            rotationDegrees: result.rotationDegrees
        )
        let theta = CGFloat(result.rotationDegrees) * .pi / 180
        let c = cos(theta)
        let s = sin(theta)

        // オフセットを写真ローカル軸 (u, v) に射影
        let offsetX = result.offset.width * cell.width
        let offsetY = result.offset.height * cell.height
        var u = offsetX * c + offsetY * s
        var v = -offsetX * s + offsetY * c

        // 各軸の遊び = (写真サイズ − セル外接サイズ) / 2
        let maxU = max(0, (size.width - (cell.width * abs(c) + cell.height * abs(s))) / 2)
        let maxV = max(0, (size.height - (cell.width * abs(s) + cell.height * abs(c))) / 2)
        u = min(max(u, -maxU), maxU)
        v = min(max(v, -maxV), maxV)

        // キャンバス座標へ戻す
        result.offset.width = (u * c - v * s) / cell.width
        result.offset.height = (u * s + v * c) / cell.height
        return result
    }
}
