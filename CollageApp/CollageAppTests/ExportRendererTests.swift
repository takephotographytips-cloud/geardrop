import XCTest
@testable import CollageApp

/// ExportRenderer の出力解像度計算テスト。
final class ExportRendererTests: XCTestCase {

    private let accuracy: CGFloat = 0.01
    private let wideRange: ClosedRange<CGFloat> = 2048...8192

    private func spec(ratio: CanvasRatio) -> CanvasSpec {
        CanvasSpec(ratio: ratio, marginFraction: 0.05, gutterFraction: 0.02, background: .white)
    }

    /// 4:5・縦2枚・4000×3000（3:2 横）2枚:
    /// 単位キャンバスでの描画幅 0.72 → 必要長辺 = 4000 ÷ 0.72 ≈ 5555.56。
    /// どの写真も元解像度を超えて引き伸ばされない。
    func testRequiredLongSide_verticalTwoPhotos() {
        let longSide = ExportRenderer.requiredLongSide(
            orientedPixelSizes: [CGSize(width: 4000, height: 3000), CGSize(width: 4000, height: 3000)],
            transforms: [CellTransform(), CellTransform()],
            layout: .verticalStack,
            spec: spec(ratio: .fourFive),
            clampedTo: wideRange
        )
        XCTAssertEqual(longSide, 4000.0 / 0.72, accuracy: accuracy)
    }

    /// ズームすると写真の見える範囲が減るため、必要な出力解像度は下がる。
    func testRequiredLongSide_zoomReducesRequiredResolution() {
        let zoomed = CellTransform(scale: 2, offset: .zero, rotationDegrees: 0)
        let longSide = ExportRenderer.requiredLongSide(
            orientedPixelSizes: [CGSize(width: 4000, height: 3000), CGSize(width: 4000, height: 3000)],
            transforms: [zoomed, zoomed],
            layout: .verticalStack,
            spec: spec(ratio: .fourFive),
            clampedTo: wideRange
        )
        XCTAssertEqual(longSide, 4000.0 / 1.44, accuracy: accuracy)
    }

    /// 1:1・横3枚・6000×4000: セルは縦長なので高さ合わせのカバー →
    /// 描画幅 0.9 × 1.5 = 1.35 → 必要長辺 = 6000 ÷ 1.35 ≈ 4444.44。
    func testRequiredLongSide_horizontalThreePhotos() {
        let sizes = [CGSize](repeating: CGSize(width: 6000, height: 4000), count: 3)
        let longSide = ExportRenderer.requiredLongSide(
            orientedPixelSizes: sizes,
            transforms: [CellTransform](repeating: CellTransform(), count: 3),
            layout: .horizontalRow,
            spec: spec(ratio: .square),
            clampedTo: wideRange
        )
        XCTAssertEqual(longSide, 6000.0 / 1.35, accuracy: accuracy)
    }

    /// 範囲外の値はクランプされる（低解像度写真→下限、超高解像度→上限）。
    func testRequiredLongSide_clamping() {
        let small = ExportRenderer.requiredLongSide(
            orientedPixelSizes: [CGSize(width: 800, height: 600), CGSize(width: 800, height: 600)],
            transforms: [],
            layout: .verticalStack,
            spec: spec(ratio: .fourFive),
            clampedTo: wideRange
        )
        XCTAssertEqual(small, wideRange.lowerBound, accuracy: accuracy)

        let large = ExportRenderer.requiredLongSide(
            orientedPixelSizes: [CGSize(width: 12000, height: 9000), CGSize(width: 12000, height: 9000)],
            transforms: [],
            layout: .verticalStack,
            spec: spec(ratio: .fourFive),
            clampedTo: 2048...4096
        )
        XCTAssertEqual(large, 4096, accuracy: accuracy)
    }
}
