import XCTest
@testable import CollageApp

/// CellGeometry（カバーフィット＋セル内変形）のテスト。
final class CellGeometryTests: XCTestCase {

    private let accuracy: CGFloat = 0.001

    /// デフォルト変形（scale 1・offset 0）で写真がセル全体を覆い、中央に配置される。
    /// 3:2 の写真をセル 720×452 に配置 → 幅を合わせて 720×480、上下に14pxずつはみ出す。
    func testImageRect_defaultTransform_coversAndCenters() {
        let cell = CGRect(x: 0, y: 0, width: 720, height: 452)
        let rect = CellGeometry.imageRect(imageRatio: 1.5, cell: cell, transform: CellTransform())
        XCTAssertEqual(rect.minX, 0, accuracy: accuracy)
        XCTAssertEqual(rect.minY, -14, accuracy: accuracy)
        XCTAssertEqual(rect.width, 720, accuracy: accuracy)
        XCTAssertEqual(rect.height, 480, accuracy: accuracy)
        XCTAssertTrue(rect.contains(cell))
    }

    /// セルより横長の写真は高さを合わせ、横がはみ出す。
    func testImageRect_wideImage_matchesCellHeight() {
        let cell = CGRect(x: 0, y: 0, width: 720, height: 452)
        let rect = CellGeometry.imageRect(imageRatio: 2.0, cell: cell, transform: CellTransform())
        XCTAssertEqual(rect.height, 452, accuracy: accuracy)
        XCTAssertEqual(rect.width, 904, accuracy: accuracy)
        XCTAssertTrue(rect.contains(cell))
    }

    /// 拡大すると描画サイズが比例して大きくなる。
    func testImageRect_scaleEnlarges() {
        let cell = CGRect(x: 0, y: 0, width: 720, height: 452)
        let transform = CellTransform(scale: 2, offset: .zero, rotationDegrees: 0)
        let rect = CellGeometry.imageRect(imageRatio: 1.5, cell: cell, transform: transform)
        XCTAssertEqual(rect.width, 1440, accuracy: accuracy)
        XCTAssertEqual(rect.height, 960, accuracy: accuracy)
        XCTAssertTrue(rect.contains(cell))
    }

    /// scale はカバー状態（1）が下限、5 が上限にクランプされる。
    func testClamped_scaleRange() {
        let cell = CGRect(x: 0, y: 0, width: 100, height: 100)
        let tooSmall = CellGeometry.clamped(
            CellTransform(scale: 0.5, offset: .zero, rotationDegrees: 0),
            imageRatio: 1.0, cell: cell
        )
        XCTAssertEqual(tooSmall.scale, 1, accuracy: accuracy)
        let tooLarge = CellGeometry.clamped(
            CellTransform(scale: 10, offset: .zero, rotationDegrees: 0),
            imageRatio: 1.0, cell: cell
        )
        XCTAssertEqual(tooLarge.scale, 5, accuracy: accuracy)
    }

    /// 過大なオフセットは「セルの外（背景）が見えない」範囲にクランプされる。
    func testImageRect_excessiveOffset_stillCoversCell() {
        let cell = CGRect(x: 0, y: 0, width: 720, height: 452)
        let transform = CellTransform(
            scale: 1,
            offset: CGSize(width: 10, height: 10),
            rotationDegrees: 0
        )
        let rect = CellGeometry.imageRect(imageRatio: 1.5, cell: cell, transform: transform)
        // 3:2 写真は横方向に遊びがない → X は動かない。Y は最大 14px まで。
        XCTAssertEqual(rect.minX, 0, accuracy: accuracy)
        XCTAssertEqual(rect.minY, 0, accuracy: accuracy)
        XCTAssertTrue(rect.contains(cell))
    }

    /// 正方形写真と正方形セル（遊びゼロ）ではオフセットが常に 0 に固定される。
    func testClamped_noSlack_offsetLockedToZero() {
        let cell = CGRect(x: 0, y: 0, width: 500, height: 500)
        let clamped = CellGeometry.clamped(
            CellTransform(scale: 1, offset: CGSize(width: 0.3, height: -0.4), rotationDegrees: 0),
            imageRatio: 1.0, cell: cell
        )
        XCTAssertEqual(clamped.offset.width, 0, accuracy: accuracy)
        XCTAssertEqual(clamped.offset.height, 0, accuracy: accuracy)
    }

    // MARK: - 回転（水平・90°補正、Stack Pro）

    /// 45°回転した正方形写真は、対角線ぶん拡大されてセルを覆う。
    /// カバーサイズ = 100 × (cos45° + sin45°) ≈ 141.421。
    func testImageRect_rotation45_coversWithDiagonal() {
        let cell = CGRect(x: 0, y: 0, width: 100, height: 100)
        let transform = CellTransform(scale: 1, offset: .zero, rotationDegrees: 45)
        let rect = CellGeometry.imageRect(imageRatio: 1.0, cell: cell, transform: transform)
        XCTAssertEqual(rect.width, 141.421, accuracy: 0.01)
        XCTAssertEqual(rect.height, 141.421, accuracy: 0.01)
        XCTAssertEqual(rect.midX, 50, accuracy: accuracy)
        XCTAssertEqual(rect.midY, 50, accuracy: accuracy)
    }

    /// 90°回転: 横長セル 200×100・写真比率 1.5 → 写真は 300×200 が必要
    /// （回転後の見た目 200×300 がセルを覆う）。
    func testImageRect_rotation90_swapsCoverAxes() {
        let cell = CGRect(x: 0, y: 0, width: 200, height: 100)
        let transform = CellTransform(scale: 1, offset: .zero, rotationDegrees: 90)
        let rect = CellGeometry.imageRect(imageRatio: 1.5, cell: cell, transform: transform)
        XCTAssertEqual(rect.width, 300, accuracy: accuracy)
        XCTAssertEqual(rect.height, 200, accuracy: accuracy)
    }

    /// 回転0では従来のカバーフィットと完全一致（回帰確認）。
    func testCoverSize_zeroRotation_matchesLegacy() {
        let cell = CGRect(x: 0, y: 0, width: 720, height: 452)
        let size = CellGeometry.coverSize(imageRatio: 1.5, cell: cell, scale: 1, rotationDegrees: 0)
        XCTAssertEqual(size.width, 720, accuracy: accuracy)
        XCTAssertEqual(size.height, 480, accuracy: accuracy)
    }

    /// 45°・正方形・scale1 は遊びゼロ → オフセットは完全ロック。
    func testClamped_rotation45_offsetLocked() {
        let cell = CGRect(x: 0, y: 0, width: 100, height: 100)
        let clamped = CellGeometry.clamped(
            CellTransform(scale: 1, offset: CGSize(width: 0.3, height: -0.2), rotationDegrees: 45),
            imageRatio: 1.0, cell: cell
        )
        XCTAssertEqual(clamped.offset.width, 0, accuracy: accuracy)
        XCTAssertEqual(clamped.offset.height, 0, accuracy: accuracy)
    }

    /// 90°回転時のオフセットクランプ: 写真ローカル軸での遊びに従う。
    /// cell 200×100・ratio 1.5 → 写真 300×200。横方向の遊び0・縦方向の遊び±100
    /// → offset (0.5, 0.5) は (0, 0.5) にクランプされる（Python 照合済み）。
    func testClamped_rotation90_projectsOntoPhotoAxes() {
        let cell = CGRect(x: 0, y: 0, width: 200, height: 100)
        let clamped = CellGeometry.clamped(
            CellTransform(scale: 1, offset: CGSize(width: 0.5, height: 0.5), rotationDegrees: 90),
            imageRatio: 1.5, cell: cell
        )
        XCTAssertEqual(clamped.offset.width, 0, accuracy: accuracy)
        XCTAssertEqual(clamped.offset.height, 0.5, accuracy: accuracy)
    }

    /// 回転してもクランプ後の写真は常にセルの4隅を覆う（総当たり不変条件）。
    func testClamped_rotated_alwaysCoversCellCorners() {
        let cell = CGRect(x: 0, y: 0, width: 720, height: 452)
        for ratio in [0.8, 1.0, 1.5] as [CGFloat] {
            for scale in [1.0, 2.0] as [CGFloat] {
                for degrees in [-15.0, -5.0, 0.0, 7.0, 15.0, 90.0, 95.0] {
                    for offset in [CGSize(width: -1, height: 0.5), .zero, CGSize(width: 0.4, height: -0.5)] {
                        let clamped = CellGeometry.clamped(
                            CellTransform(scale: scale, offset: offset, rotationDegrees: degrees),
                            imageRatio: ratio, cell: cell
                        )
                        let size = CellGeometry.coverSize(
                            imageRatio: ratio, cell: cell,
                            scale: clamped.scale, rotationDegrees: clamped.rotationDegrees
                        )
                        let theta = CGFloat(clamped.rotationDegrees) * .pi / 180
                        let c = cos(theta), s = sin(theta)
                        let ox = clamped.offset.width * cell.width
                        let oy = clamped.offset.height * cell.height
                        for signX in [-1.0, 1.0] as [CGFloat] {
                            for signY in [-1.0, 1.0] as [CGFloat] {
                                let px = signX * cell.width / 2 - ox
                                let py = signY * cell.height / 2 - oy
                                let localX = px * c + py * s
                                let localY = -px * s + py * c
                                XCTAssertLessThanOrEqual(
                                    abs(localX), size.width / 2 + 0.01,
                                    "r=\(ratio) s=\(scale) θ=\(degrees) offset=\(offset): X方向で背景が見える"
                                )
                                XCTAssertLessThanOrEqual(
                                    abs(localY), size.height / 2 + 0.01,
                                    "r=\(ratio) s=\(scale) θ=\(degrees) offset=\(offset): Y方向で背景が見える"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /// 90°単位と水平微調整の分解・角度の正規化。
    func testRotationDecomposition() {
        XCTAssertEqual(CellTransform(scale: 1, offset: .zero, rotationDegrees: 95).quarterTurnsDegrees, 90)
        XCTAssertEqual(CellTransform(scale: 1, offset: .zero, rotationDegrees: 95).fineAngleDegrees, 5, accuracy: 0.001)
        XCTAssertEqual(CellTransform(scale: 1, offset: .zero, rotationDegrees: -100).quarterTurnsDegrees, -90)
        XCTAssertEqual(CellTransform(scale: 1, offset: .zero, rotationDegrees: -100).fineAngleDegrees, -10, accuracy: 0.001)
        XCTAssertEqual(CellTransform.normalizedDegrees(270), -90, accuracy: 0.001)
        XCTAssertEqual(CellTransform.normalizedDegrees(-190), 170, accuracy: 0.001)
        XCTAssertEqual(CellTransform.normalizedDegrees(360), 0, accuracy: 0.001)
    }

    /// 正規化オフセットのため、同じ変形状態を異なるセルサイズに適用しても
    /// 相対位置が保たれる（レイアウト変更時の位置維持の根拠）。
    func testImageRect_normalizedOffset_scalesWithCellSize() {
        let transform = CellTransform(scale: 2, offset: CGSize(width: 0.1, height: 0.1), rotationDegrees: 0)
        let smallCell = CGRect(x: 0, y: 0, width: 100, height: 100)
        let largeCell = CGRect(x: 0, y: 0, width: 200, height: 200)
        let smallRect = CellGeometry.imageRect(imageRatio: 1.0, cell: smallCell, transform: transform)
        let largeRect = CellGeometry.imageRect(imageRatio: 1.0, cell: largeCell, transform: transform)
        // 2倍のセルなら描画矩形も相似で2倍になる
        XCTAssertEqual(largeRect.minX, smallRect.minX * 2, accuracy: accuracy)
        XCTAssertEqual(largeRect.minY, smallRect.minY * 2, accuracy: accuracy)
        XCTAssertEqual(largeRect.width, smallRect.width * 2, accuracy: accuracy)
        XCTAssertEqual(largeRect.height, smallRect.height * 2, accuracy: accuracy)
    }
}
