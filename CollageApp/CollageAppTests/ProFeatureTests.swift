import XCTest
@testable import CollageApp

/// Stack Pro 関連（プリセット数制限・デザインフレーム）のテスト。
final class ProFeatureTests: XCTestCase {

    private let accuracy: CGFloat = 0.001

    // MARK: - プリセット数制限（無料3つまで）

    func testCanAddPreset_freeLimit() {
        XCTAssertTrue(PresetStore.canAddPreset(currentCount: 0, isPro: false))
        XCTAssertTrue(PresetStore.canAddPreset(currentCount: 2, isPro: false))
        XCTAssertFalse(PresetStore.canAddPreset(currentCount: 3, isPro: false))
        XCTAssertFalse(PresetStore.canAddPreset(currentCount: 10, isPro: false))
        // Pro は無制限
        XCTAssertTrue(PresetStore.canAddPreset(currentCount: 3, isPro: true))
        XCTAssertTrue(PresetStore.canAddPreset(currentCount: 100, isPro: true))
    }

    // MARK: - フレーム

    func testFrameBandInsets() {
        // なし: 帯ゼロ
        let none = FrameStyle.none.bandInsets(layout: .verticalStack, shortSide: 1000)
        XCTAssertEqual(none, FrameStyle.BandInsets())

        // フィルム縦並び: 左右に帯、上下なし
        let filmVertical = FrameStyle.film.bandInsets(layout: .verticalStack, shortSide: 1000)
        XCTAssertGreaterThan(filmVertical.leading, 0)
        XCTAssertGreaterThan(filmVertical.trailing, 0)
        XCTAssertEqual(filmVertical.top, 0)
        XCTAssertEqual(filmVertical.bottom, 0)

        // フィルム横並び: 上下に帯
        let filmHorizontal = FrameStyle.film.bandInsets(layout: .horizontalRow, shortSide: 1000)
        XCTAssertGreaterThan(filmHorizontal.top, 0)
        XCTAssertGreaterThan(filmHorizontal.bottom, 0)
        XCTAssertEqual(filmHorizontal.leading, 0)
    }

    func testFrameShrinksCells() {
        let canvasSize = CGSize(width: 800, height: 1000)
        let plainSpec = CanvasSpec()
        var framedSpec = plainSpec
        framedSpec.frame = .film
        let plain = CollageLayout.verticalStack.cellRects(canvasSize: canvasSize, spec: plainSpec, count: 2)
        let framed = CollageLayout.verticalStack.cellRects(canvasSize: canvasSize, spec: framedSpec, count: 2)
        XCTAssertLessThan(framed[0].width, plain[0].width)
        XCTAssertGreaterThan(framed[0].minX, plain[0].minX)
    }

    /// センターフォーカスレイアウトのみ Pro 限定。
    func testProLayouts() {
        XCTAssertFalse(CollageLayout.verticalStack.isPro)
        XCTAssertFalse(CollageLayout.horizontalRow.isPro)
        XCTAssertTrue(CollageLayout.centerFocus.isPro)
    }

    /// Pro フレームは装飾要素を生成し、すべてキャンバス内に収まる。
    func testDecorationElements_withinCanvas() {
        for frame in FrameStyle.allCases where frame != .none {
            for layout in [CollageLayout.verticalStack, .horizontalRow, .centerFocus] {
                for count in [1, 3, 6] {
                    var spec = CanvasSpec()
                    spec.frame = frame
                    let canvasSize = spec.ratio.size(longSide: 2048)
                    let canvasRect = CGRect(origin: .zero, size: canvasSize)
                    let cells = layout.cellRects(canvasSize: canvasSize, spec: spec, count: count)
                    let elements = frame.decorationElements(
                        canvasSize: canvasSize, spec: spec, layout: layout, cells: cells
                    )
                    XCTAssertFalse(elements.isEmpty, "\(frame) \(layout) x\(count): 装飾が空")
                    for element in elements {
                        switch element {
                        case .roundedRect(let rect, _, _):
                            XCTAssertTrue(
                                canvasRect.insetBy(dx: -accuracy, dy: -accuracy).contains(rect),
                                "\(frame) \(layout) x\(count): \(rect) がキャンバス外"
                            )
                        case .text(_, let center, _, _, _):
                            XCTAssertTrue(
                                canvasRect.contains(center),
                                "\(frame) \(layout) x\(count): テキスト中心 \(center) がキャンバス外"
                            )
                        }
                    }
                }
            }
        }
    }

    /// なしフレームは装飾なし・セルにも影響しない。
    func testNoneFrame_noDecorations() {
        let spec = CanvasSpec()
        let canvasSize = spec.ratio.size(longSide: 2048)
        let cells = CollageLayout.verticalStack.cellRects(canvasSize: canvasSize, spec: spec, count: 2)
        XCTAssertTrue(FrameStyle.none.decorationElements(
            canvasSize: canvasSize, spec: spec, layout: .verticalStack, cells: cells
        ).isEmpty)
        XCTAssertNil(FrameStyle.none.backgroundOverride)
    }

    // MARK: - 後方互換

    /// 旧バージョン（frame キーなし）で保存された CanvasSpec が読める。
    func testCanvasSpecDecoding_withoutFrameKey_defaultsToNone() throws {
        let legacyJSON = """
        {"ratio":"4:5","marginFraction":0.08,"gutterFraction":0.03,"background":{"red":1,"green":1,"blue":1}}
        """
        let spec = try JSONDecoder().decode(CanvasSpec.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(spec.frame, .none)
        XCTAssertEqual(spec.ratio, .fourFive)
        XCTAssertEqual(spec.marginFraction, 0.08, accuracy: accuracy)
    }

    func testSessionSnapshotCodableRoundTrip() throws {
        let snapshot = SessionStore.Snapshot(
            spec: CanvasSpec(
                ratio: .threeTwo,
                marginFraction: 0.08,
                gutterFraction: 0.03,
                background: CanvasColor(red: 0.5, green: 0.6, blue: 0.7),
                frame: .film
            ),
            layoutIndex: 1,
            transforms: [
                CellTransform(scale: 2, offset: CGSize(width: 0.1, height: -0.2), rotationDegrees: 0),
                CellTransform(),
            ],
            photoCount: 2
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SessionStore.Snapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testPresetCodableRoundTrip() throws {
        let preset = Preset(
            name: "テスト",
            layout: .horizontalRow,
            spec: CanvasSpec(ratio: .square, marginFraction: 0.1, gutterFraction: 0.05, background: .black, frame: .print)
        )
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(Preset.self, from: data)
        XCTAssertEqual(decoded, preset)
    }
}
