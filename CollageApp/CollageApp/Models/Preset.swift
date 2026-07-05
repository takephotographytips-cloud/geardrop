import Foundation

/// 保存プリセット = レイアウト＋キャンバス設定の組み合わせ（仕様 1.4）。
struct Preset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var layout: CollageLayout
    var spec: CanvasSpec
    var createdAt: Date = Date()
}

/// 課金プリセットパック（StoreKit 2 非消耗型、各¥480）。
/// パックの中身はアプリ内蔵で、購入するとホームのプリセット一覧に現れる。
struct PresetPack: Identifiable {
    let productID: String
    let name: String
    let tagline: String
    let presets: [Preset]

    var id: String { productID }

    static let all: [PresetPack] = [gallery, film, editorial]

    /// 写真展のギャラリーのような広い余白と端正な並び
    static let gallery = PresetPack(
        productID: "com.dstudio.collageapp.pack.gallery",
        name: "Gallery Pack",
        tagline: "写真展のような広い余白と端正な並び",
        presets: [
            Preset(
                name: "ギャラリー",
                layout: .verticalStack,
                spec: CanvasSpec(ratio: .fourFive, marginFraction: 0.10, gutterFraction: 0.04, background: .offWhite)
            ),
            Preset(
                name: "ホワイトキューブ",
                layout: .verticalStack,
                spec: CanvasSpec(ratio: .square, marginFraction: 0.12, gutterFraction: 0.05, background: .white)
            ),
            Preset(
                name: "ギャラリーワイド",
                layout: .horizontalRow,
                spec: CanvasSpec(ratio: .threeTwo, marginFraction: 0.08, gutterFraction: 0.03, background: .offWhite)
            ),
            Preset(
                name: "ミニマル",
                layout: .horizontalRow,
                spec: CanvasSpec(ratio: .fourFive, marginFraction: 0.06, gutterFraction: 0.02, background: .white)
            ),
        ]
    )

    /// 暗室・フィルムの世界観（黒基調）
    static let film = PresetPack(
        productID: "com.dstudio.collageapp.pack.film",
        name: "Film Pack",
        tagline: "暗室のような黒基調のフィルムルック",
        presets: [
            Preset(
                name: "ノワール",
                layout: .verticalStack,
                spec: CanvasSpec(ratio: .threeTwo, marginFraction: 0.08, gutterFraction: 0.03, background: .black)
            ),
            Preset(
                name: "コンタクトシート",
                layout: .horizontalRow,
                spec: CanvasSpec(ratio: .threeTwo, marginFraction: 0.05, gutterFraction: 0.02, background: .black)
            ),
            Preset(
                name: "ダークルーム",
                layout: .verticalStack,
                spec: CanvasSpec(
                    ratio: .fourFive, marginFraction: 0.10, gutterFraction: 0.04,
                    background: CanvasColor(red: 0.11, green: 0.11, blue: 0.12)
                )
            ),
            Preset(
                name: "モノリス",
                layout: .verticalStack,
                spec: CanvasSpec(ratio: .nineSixteen, marginFraction: 0.07, gutterFraction: 0.025, background: .black)
            ),
        ]
    )

    /// 雑誌・エディトリアルの誌面的レイアウト
    static let editorial = PresetPack(
        productID: "com.dstudio.collageapp.pack.editorial",
        name: "Editorial Pack",
        tagline: "雑誌の誌面のようなタイトな組み",
        presets: [
            Preset(
                name: "カバー",
                layout: .verticalStack,
                spec: CanvasSpec(ratio: .nineSixteen, marginFraction: 0.05, gutterFraction: 0.02, background: .white)
            ),
            Preset(
                name: "スプレッド",
                layout: .horizontalRow,
                spec: CanvasSpec(ratio: .fourThree, marginFraction: 0.04, gutterFraction: 0.015, background: .white)
            ),
            Preset(
                name: "ルックブック",
                layout: .verticalStack,
                spec: CanvasSpec(ratio: .fourFive, marginFraction: 0.03, gutterFraction: 0.01, background: .white)
            ),
            Preset(
                name: "ストーリーズ",
                layout: .horizontalRow,
                spec: CanvasSpec(ratio: .nineSixteen, marginFraction: 0.06, gutterFraction: 0.03, background: .offWhite)
            ),
        ]
    )
}
