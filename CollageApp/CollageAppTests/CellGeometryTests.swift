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
