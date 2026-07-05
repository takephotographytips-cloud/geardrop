# Stack (CollageApp) — 複数写真コラージュアプリ

写真(1〜6枚)を美しい余白で1枚の"作品"にする、3タップ完結のコラージュアプリ。
仕様書: `collage_app_spec_for_claude_code.md` v1.0

## 実装状況

### Phase 1: コア体験 ✅
- [x] タップ1: 起動直後に PhotosPicker が自動で開く。1〜6枚選択(選んだ順=配置順、`selectionBehavior: .ordered`)。1枚のときは全面1セル(レイアウト切替は非表示)
- [x] タップ2: 選択と同時にレイアウト自動生成 → プレビュー
- [x] タップ3: 保存 → フォトライブラリへ書き出し(Phase 1 はプレビュー解像度 長辺2048px)
- [x] 比率5種(1:1 / 4:5 / 3:2 / 9:16 / 4:3)
- [x] 余白スライダー(0〜15%)+ 背景色 白/黒/オフホワイト #F5F2ED
- [x] Undo/Redo(調整・写真操作のスナップショット)

### 仕様変更 v1.1: Instagram / Canva 型編集 ✅(このコミット)
- [x] レイアウトは縦並び / 横並びの2パターン(セグメント切替)。セルは枚数で**均等分割**
  - 縦並び: セル高さ = (利用可能高さ − ガター合計) ÷ 枚数、幅共通
  - 横並び: セル幅 = (利用可能幅 − ガター合計) ÷ 枚数、高さ共通
- [x] 写真はセルいっぱいに表示(BoxFit.cover 相当)。枠からはみ出た部分はクリップ
- [x] 枠は固定、写真だけをドラッグ移動・ピンチ拡大縮小(セルごとに完全独立)
- [x] 変形状態は `CellTransform`(scale / offset / rotation※将来用)としてセルごとに保持
  - offset はセル寸法で正規化 → レイアウト変更後もズーム率・位置を可能な限り維持
  - 「背景が見えない」範囲へ自動クランプ(scale 下限 = カバー状態)
- [x] プレビューと書き出しは同じ `CellGeometry` を通り、見た目が一致
- [x] `CollageLayout`(均等分割)+ `CellGeometry`(カバー+変形)のユニットテスト

### Phase 2〜4(未実装)
- ExportRenderer のフル解像度化(16bit 合成・Display P3・EXIF 保持)
- スポイト+カラーピッカー、ガター(間隔)スライダー
- プリセット保存/呼び出し UI、StoreKit 2 プリセットパック
- リリース準備(アイコン・スクリーンショット)

## 要件

- Xcode 16 以降(プロジェクトは filesystem-synchronized groups / objectVersion 77 を使用)
- iOS 17.0+ / SwiftUI / 外部依存ゼロ

## ビルド・テスト

```bash
# シミュレータビルド
xcodebuild build \
  -project CollageApp.xcodeproj \
  -scheme CollageApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# ユニットテスト(CollageLayout の矩形計算)
xcodebuild test \
  -project CollageApp.xcodeproj \
  -scheme CollageApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

GitHub Actions の `iOS Build & Test` ワークフロー(手動実行)でも同じ確認ができる。

## 構成(仕様 3.3 準拠)

```
CollageApp/
├── App/CollageApp.swift            エントリポイント
├── Models/
│   ├── CollageLayout.swift         レイアウト定義(縦/横の均等分割セル計算)
│   ├── CellTransform.swift         セル内変形状態 + カバーフィット矩形計算(CellGeometry)
│   ├── CanvasSpec.swift            比率・余白・ガター・背景色
│   └── Preset.swift                Codable プリセット
├── ViewModels/EditorViewModel.swift  @Observable。セル変形・Undo/Redo スタック含む
├── Views/
│   ├── HomeView.swift              画面A: ホーム
│   ├── EditorView.swift            画面B: エディタ(レイアウト切替セグメント)
│   ├── CollageCanvas.swift         キャンバス+セル(ドラッグ/ピンチのジェスチャー処理)
│   └── AdjustPanel.swift           余白・色・比率の調整パネル
├── Rendering/
│   ├── CollageRenderer.swift       プレビュー解像度の合成
│   └── ExportRenderer.swift        フォトライブラリ書き出し(Phase 2 でフル解像度化)
└── Store/PresetStore.swift         JSON 永続化(StoreKit 2 は Phase 3)
```
