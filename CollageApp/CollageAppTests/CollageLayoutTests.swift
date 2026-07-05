import XCTest
@testable import CollageApp

/// CollageLayout（v1.1: 均等分割セル）の矩形計算テスト。
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

    // MARK: - レイアウト候補

    func testCandidatesPerPhotoCount() {
        for count in 1...6 {
            XCTAssertEqual(CollageLayout.candidates(for: count), [.verticalStack, .horizontalRow])
        }
        XCTAssertTrue(CollageLayout.candidates(for: 0).isEmpty)
        XCTAssertTrue(CollageLayout.candidates(for: 7).isEmpty)
    }

    /// 1枚のときは縦・横ともコンテンツ領域全体の1セルになる。
    func testSinglePhoto_cellFillsContentArea() {
        let canvasSize = CGSize(width: 800, height: 1000)
        for layout in CollageLayout.candidates(for: 1) {
            let cells = layout.cellRects(
                canvasSize: canvasSize,
                spec: spec(ratio: .fourFive),
                count: 1
            )
            XCTAssertEqual(cells.count, 1)
            assertRect(cells[0], x: 40, y: 40, width: 720, height: 920)
        }
    }

    // MARK: - 縦並び: 高さ均等・幅共通

    /// キャンバス 800×1000（4:5）、余白5%（=40px）、ガター2%（=16px）、2枚。
    /// セル高さ = (920 − 16) ÷ 2 = 452、幅は 720 で共通。
    func testVerticalStack_ratio45_margin5_twoCells() {
        let cells = CollageLayout.verticalStack.cellRects(
            canvasSize: CGSize(width: 800, height: 1000),
            spec: spec(ratio: .fourFive),
            count: 2
        )
        XCTAssertEqual(cells.count, 2)
        assertRect(cells[0], x: 40, y: 40, width: 720, height: 452)
        assertRect(cells[1], x: 40, y: 508, width: 720, height: 452)
    }

    /// 3枚: セル高さ = (920 − 32) ÷ 3 = 296。3枚とも高さ・幅が完全に同じ。
    func testVerticalStack_threeCells_equalHeights() {
        let cells = CollageLayout.verticalStack.cellRects(
            canvasSize: CGSize(width: 800, height: 1000),
            spec: spec(ratio: .fourFive),
            count: 3
        )
        XCTAssertEqual(cells.count, 3)
        assertRect(cells[0], x: 40, y: 40, width: 720, height: 296)
        assertRect(cells[1], x: 40, y: 352, width: 720, height: 296)
        assertRect(cells[2], x: 40, y: 664, width: 720, height: 296)
    }

    // MARK: - 横並び: 幅均等・高さ共通

    /// キャンバス 1000×1000、余白5%（=50px）、ガター2%（=20px）、3枚。
    /// セル幅 = (900 − 40) ÷ 3 = 286.667、高さは 900 で共通。
    func testHorizontalRow_threeCells_equalWidths() {
        let cells = CollageLayout.horizontalRow.cellRects(
            canvasSize: CGSize(width: 1000, height: 1000),
            spec: spec(ratio: .square),
            count: 3
        )
        XCTAssertEqual(cells.count, 3)
        let cellWidth: CGFloat = (900.0 - 40.0) / 3.0
        assertRect(cells[0], x: 50, y: 50, width: cellWidth, height: 900)
        assertRect(cells[1], x: 50 + cellWidth + 20, y: 50, width: cellWidth, height: 900)
        assertRect(cells[2], x: 50 + (cellWidth + 20) * 2, y: 50, width: cellWidth, height: 900)
    }

    // MARK: - 不変条件: 均等サイズ・コンテンツ領域に収まる

    /// 全レイアウト・全比率・全枚数で、セルサイズが完全に均等であること。
    func testCellRects_equalSizes_allLayouts() {
        for count in 1...6 {
            for layout in CollageLayout.candidates(for: count) {
                for canvasRatio in CanvasRatio.allCases {
                    let cells = layout.cellRects(
                        canvasSize: canvasRatio.size(longSide: 2048),
                        spec: spec(ratio: canvasRatio),
                        count: count
                    )
                    XCTAssertEqual(cells.count, count)
                    guard let first = cells.first else { continue }
                    for cell in cells {
                        XCTAssertEqual(cell.width, first.width, accuracy: accuracy,
                                       "\(layout) x\(count) \(canvasRatio.rawValue): 幅が不均等")
                        XCTAssertEqual(cell.height, first.height, accuracy: accuracy,
                                       "\(layout) x\(count) \(canvasRatio.rawValue): 高さが不均等")
                    }
                }
            }
        }
    }

    /// 全レイアウトで、セルが余白の内側（コンテンツ領域）にちょうど収まる。
    func testCellRects_fillContentArea_allLayouts() {
        for count in 1...6 {
            for layout in CollageLayout.candidates(for: count) {
                for canvasRatio in CanvasRatio.allCases {
                    let canvasSize = canvasRatio.size(longSide: 2048)
                    let testSpec = spec(ratio: canvasRatio)
                    let margin = testSpec.marginFraction * min(canvasSize.width, canvasSize.height)
                    let content = CGRect(origin: .zero, size: canvasSize)
                        .insetBy(dx: margin, dy: margin)
                    let cells = layout.cellRects(canvasSize: canvasSize, spec: testSpec, count: count)
                    let union = cells.reduce(CGRect.null) { $0.union($1) }
                    XCTAssertEqual(union.minX, content.minX, accuracy: accuracy)
                    XCTAssertEqual(union.minY, content.minY, accuracy: accuracy)
                    XCTAssertEqual(union.maxX, content.maxX, accuracy: accuracy)
                    XCTAssertEqual(union.maxY, content.maxY, accuracy: accuracy)
                }
            }
        }
    }

    /// 余白0%・ガター0%でも計算が破綻しない。
    func testCellRects_zeroMarginAndGutter() {
        let zeroSpec = CanvasSpec(ratio: .square, marginFraction: 0, gutterFraction: 0, background: .white)
        let cells = CollageLayout.verticalStack.cellRects(
            canvasSize: CGSize(width: 1000, height: 1000),
            spec: zeroSpec,
            count: 2
        )
        XCTAssertEqual(cells.count, 2)
        assertRect(cells[0], x: 0, y: 0, width: 1000, height: 500)
        assertRect(cells[1], x: 0, y: 500, width: 1000, height: 500)
    }
}
