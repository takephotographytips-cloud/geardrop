import XCTest
@testable import CollageApp

/// CollageLayout の矩形計算テスト（仕様セクション6の指示に基づく）。
final class CollageLayoutTests: XCTestCase {

    private let accuracy: CGFloat = 0.001

    /// margin 5% / gutter 2% / 白背景の標準テスト設定
    private func spec(ratio: CanvasRatio) -> CanvasSpec {
        CanvasSpec(ratio: ratio, marginFraction: 0.05, gutterFraction: 0.02, background: .white)
    }

    private func assertRect(
        _ rect: CGRect,
        x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(rect.minX, x, accuracy: accuracy, "minX", file: file, line: line)
        XCTAssertEqual(rect.minY, y, accuracy: accuracy, "minY", file: file, line: line)
        XCTAssertEqual(rect.width, width, accuracy: accuracy, "width", file: file, line: line)
        XCTAssertEqual(rect.height, height, accuracy: accuracy, "height", file: file, line: line)
    }

    // MARK: - レイアウト候補（仕様 2.3 の表）

    func testCandidatesPerPhotoCount() {
        XCTAssertEqual(CollageLayout.candidates(for: 2), [.verticalStack, .horizontalRow, .mainPlusSub])
        XCTAssertEqual(CollageLayout.candidates(for: 3), [.verticalStack, .oneBigTwoSmall, .horizontalRow])
        XCTAssertEqual(CollageLayout.candidates(for: 4), [.grid2x2, .verticalStack, .oneBigThreeSmall])
        XCTAssertEqual(CollageLayout.candidates(for: 5), [.grid, .verticalStack])
        XCTAssertEqual(CollageLayout.candidates(for: 6), [.grid, .verticalStack])
        XCTAssertTrue(CollageLayout.candidates(for: 1).isEmpty)
        XCTAssertTrue(CollageLayout.candidates(for: 7).isEmpty)
    }

    // MARK: - 仕様セクション6指定のケース: 比率4:5・余白5%・2枚縦積み

    /// キャンバス 800×1000（4:5）、余白5%（=40px）、ガター2%（=16px）、3:2 の写真2枚。
    /// 幅いっぱい（720px）では総高 976px が利用可能高 920px を超えるため、
    /// 幅 678px に縮小され、中央に配置される。
    func testVerticalStack_ratio45_margin5_twoLandscapePhotos() {
        let rects = CollageLayout.verticalStack.photoRects(
            canvasSize: CGSize(width: 800, height: 1000),
            spec: spec(ratio: .fourFive),
            aspectRatios: [1.5, 1.5]
        )
        XCTAssertEqual(rects.count, 2)
        assertRect(rects[0], x: 61, y: 40, width: 678, height: 452)
        assertRect(rects[1], x: 61, y: 508, width: 678, height: 452)
    }

    /// 同条件で正方形（1:1）の写真2枚。幅 452px・上下ちょうど余白に接する。
    func testVerticalStack_ratio45_margin5_twoSquarePhotos() {
        let rects = CollageLayout.verticalStack.photoRects(
            canvasSize: CGSize(width: 800, height: 1000),
            spec: spec(ratio: .fourFive),
            aspectRatios: [1.0, 1.0]
        )
        XCTAssertEqual(rects.count, 2)
        assertRect(rects[0], x: 174, y: 40, width: 452, height: 452)
        assertRect(rects[1], x: 174, y: 508, width: 452, height: 452)
    }

    /// 縦積みは全写真の幅が揃う（withgar 型の肝、仕様 2.3）
    func testVerticalStack_equalWidths_mixedRatios() {
        let rects = CollageLayout.verticalStack.photoRects(
            canvasSize: CGSize(width: 800, height: 1000),
            spec: spec(ratio: .fourFive),
            aspectRatios: [1.5, 0.8, 1.0]
        )
        XCTAssertEqual(rects.count, 3)
        XCTAssertEqual(rects[0].width, rects[1].width, accuracy: accuracy)
        XCTAssertEqual(rects[1].width, rects[2].width, accuracy: accuracy)
    }

    // MARK: - 横並び

    /// キャンバス 1000×1000、余白5%（=50px）、ガター2%（=20px）、3:2 の写真2枚。
    func testHorizontalRow_squareCanvas_twoLandscapePhotos() {
        let rects = CollageLayout.horizontalRow.photoRects(
            canvasSize: CGSize(width: 1000, height: 1000),
            spec: spec(ratio: .square),
            aspectRatios: [1.5, 1.5]
        )
        XCTAssertEqual(rects.count, 2)
        assertRect(rects[0], x: 50, y: 353.0 + 1.0 / 3.0, width: 440, height: 293.0 + 1.0 / 3.0)
        assertRect(rects[1], x: 510, y: 353.0 + 1.0 / 3.0, width: 440, height: 293.0 + 1.0 / 3.0)
    }

    // MARK: - 2×2 グリッド

    /// キャンバス 1000×1000、余白5%、ガター2% → 440×440 のセルが4つ。
    func testGrid2x2_cellRects() {
        let cells = CollageLayout.grid2x2.cellRects(
            canvasSize: CGSize(width: 1000, height: 1000),
            spec: spec(ratio: .square),
            aspectRatios: [1.0, 1.0, 1.0, 1.0]
        )
        XCTAssertEqual(cells.count, 4)
        assertRect(cells[0], x: 50, y: 50, width: 440, height: 440)
        assertRect(cells[1], x: 510, y: 50, width: 440, height: 440)
        assertRect(cells[2], x: 50, y: 510, width: 440, height: 440)
        assertRect(cells[3], x: 510, y: 510, width: 440, height: 440)
    }

    /// 5枚グリッドでは最終行の1セルが水平中央に寄る。
    func testGrid_oddCount_centersLastCell() {
        let canvasSize = CGSize(width: 1000, height: 1000)
        let cells = CollageLayout.grid.cellRects(
            canvasSize: canvasSize,
            spec: spec(ratio: .square),
            aspectRatios: [CGFloat](repeating: 1.0, count: 5)
        )
        XCTAssertEqual(cells.count, 5)
        XCTAssertEqual(cells[4].midX, canvasSize.width / 2, accuracy: accuracy)
    }

    // MARK: - 不変条件: トリミングなし（アスペクト比保持）・キャンバス内に収まる

    /// 全レイアウト・混在比率で、最終矩形が写真のアスペクト比を保持する（仕様 2.3: トリミングなし）。
    func testPhotoRects_preserveAspectRatio_allLayouts() {
        let mixedRatios: [CGFloat] = [1.5, 0.8, 1.0, 1.777, 0.5625, 1.333]
        for count in 2...6 {
            let ratios = Array(mixedRatios.prefix(count))
            for layout in CollageLayout.candidates(for: count) {
                for canvasRatio in CanvasRatio.allCases {
                    let canvasSize = canvasRatio.size(longSide: 2048)
                    let rects = layout.photoRects(
                        canvasSize: canvasSize,
                        spec: spec(ratio: canvasRatio),
                        aspectRatios: ratios
                    )
                    XCTAssertEqual(rects.count, count, "\(layout) x\(count) \(canvasRatio.rawValue)")
                    for (rect, ratio) in zip(rects, ratios) {
                        XCTAssertEqual(
                            rect.width / rect.height, ratio, accuracy: accuracy,
                            "\(layout) x\(count) \(canvasRatio.rawValue): アスペクト比が保持されていない"
                        )
                    }
                }
            }
        }
    }

    /// 全レイアウトで、最終矩形が余白の内側（コンテンツ領域）に収まる。
    func testPhotoRects_stayWithinContentArea_allLayouts() {
        let mixedRatios: [CGFloat] = [1.5, 0.8, 1.0, 1.777, 0.5625, 1.333]
        for count in 2...6 {
            let ratios = Array(mixedRatios.prefix(count))
            for layout in CollageLayout.candidates(for: count) {
                for canvasRatio in CanvasRatio.allCases {
                    let canvasSize = canvasRatio.size(longSide: 2048)
                    let testSpec = spec(ratio: canvasRatio)
                    let margin = testSpec.marginFraction * min(canvasSize.width, canvasSize.height)
                    let content = CGRect(origin: .zero, size: canvasSize)
                        .insetBy(dx: margin, dy: margin)
                        .insetBy(dx: -accuracy, dy: -accuracy)
                    let rects = layout.photoRects(
                        canvasSize: canvasSize,
                        spec: testSpec,
                        aspectRatios: ratios
                    )
                    for rect in rects {
                        XCTAssertTrue(
                            content.contains(rect),
                            "\(layout) x\(count) \(canvasRatio.rawValue): \(rect) がコンテンツ領域 \(content) をはみ出す"
                        )
                    }
                }
            }
        }
    }

    /// 余白0%でも計算が破綻しない。
    func testPhotoRects_zeroMargin() {
        let zeroMarginSpec = CanvasSpec(ratio: .square, marginFraction: 0, gutterFraction: 0, background: .white)
        let rects = CollageLayout.verticalStack.photoRects(
            canvasSize: CGSize(width: 1000, height: 1000),
            spec: zeroMarginSpec,
            aspectRatios: [1.0, 1.0]
        )
        XCTAssertEqual(rects.count, 2)
        assertRect(rects[0], x: 250, y: 0, width: 500, height: 500)
        assertRect(rects[1], x: 250, y: 500, width: 500, height: 500)
    }

    // MARK: - アスペクトフィット

    func testAspectFit_landscapePhotoInPortraitCell() {
        let cell = CGRect(x: 0, y: 0, width: 100, height: 200)
        let fitted = CollageLayout.aspectFit(ratio: 2.0, in: cell)
        assertRect(fitted, x: 0, y: 75, width: 100, height: 50)
    }

    func testAspectFit_portraitPhotoInLandscapeCell() {
        let cell = CGRect(x: 0, y: 0, width: 200, height: 100)
        let fitted = CollageLayout.aspectFit(ratio: 0.5, in: cell)
        assertRect(fitted, x: 75, y: 0, width: 50, height: 100)
    }
}
