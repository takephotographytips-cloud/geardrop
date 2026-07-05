import XCTest
@testable import CollageApp

/// プリセットパック定義とセッション永続化モデルのテスト。
final class PresetPackTests: XCTestCase {

    func testThreePacksWithUniqueProductIDs() {
        XCTAssertEqual(PresetPack.all.count, 3)
        let ids = PresetPack.all.map(\.productID)
        XCTAssertEqual(Set(ids).count, ids.count, "productID が重複している")
        for id in ids {
            XCTAssertTrue(id.hasPrefix("com.dstudio.collageapp.pack."), "productID の命名規則: \(id)")
        }
    }

    /// パック内プリセットの設定値がアプリの許容範囲に収まっていること
    /// （範囲外だとスライダーに反映できない）。
    func testPackPresetsWithinValidRanges() {
        for pack in PresetPack.all {
            XCTAssertFalse(pack.presets.isEmpty, "\(pack.name) が空")
            for preset in pack.presets {
                XCTAssertTrue(
                    CanvasSpec.marginRange.contains(preset.spec.marginFraction),
                    "\(pack.name)/\(preset.name): 余白 \(preset.spec.marginFraction) が範囲外"
                )
                XCTAssertTrue(
                    CanvasSpec.gutterRange.contains(preset.spec.gutterFraction),
                    "\(pack.name)/\(preset.name): 間隔 \(preset.spec.gutterFraction) が範囲外"
                )
            }
        }
    }

    func testSessionSnapshotCodableRoundTrip() throws {
        let snapshot = SessionStore.Snapshot(
            spec: CanvasSpec(
                ratio: .threeTwo,
                marginFraction: 0.08,
                gutterFraction: 0.03,
                background: CanvasColor(red: 0.5, green: 0.6, blue: 0.7)
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
            spec: CanvasSpec(ratio: .square, marginFraction: 0.1, gutterFraction: 0.05, background: .black)
        )
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(Preset.self, from: data)
        XCTAssertEqual(decoded, preset)
    }
}
