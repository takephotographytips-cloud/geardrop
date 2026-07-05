# Stack (CollageApp) — 複数写真コラージュアプリ

複数写真(2〜6枚)を美しい余白で1枚の"作品"にする、3タップ完結のコラージュアプリ。
仕様書: `collage_app_spec_for_claude_code.md` v1.0

## 実装状況

### Phase 1: コア体験 ✅(このコミット)
- [x] タップ1: 起動直後に PhotosPicker が自動で開く。2〜6枚選択(選んだ順=配置順、`selectionBehavior: .ordered`)
- [x] タップ2: 選択と同時にレイアウト自動生成 → プレビュー。横スワイプで候補切替(ページドット表示)
- [x] タップ3: 保存 → フォトライブラリへ書き出し(Phase 1 はプレビュー解像度 長辺2048px)
- [x] レイアウト6種(縦積み / 横並び / 大小 / 1大+2小 / 2×2 / 1大+3小 / グリッド)
- [x] 比率5種(1:1 / 4:5 / 3:2 / 9:16 / 4:3)
- [x] 余白スライダー(0〜15%)+ 背景色 白/黒/オフホワイト #F5F2ED
- [x] 写真はトリミングなし(アスペクトフィットのみ)。縦積みは幅を揃え高さは写真比率に従う
- [x] Undo/Redo(調整操作のスナップショット)
- [x] `CollageLayout` のユニットテスト(比率4:5・余白5%・2枚縦積みのセル矩形検証を含む)

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
│   ├── CollageLayout.swift         レイアウト定義(enum + セル矩形計算)
│   ├── CanvasSpec.swift            比率・余白・ガター・背景色
│   └── Preset.swift                Codable プリセット
├── ViewModels/EditorViewModel.swift  @Observable。Undo/Redo スタック含む
├── Views/
│   ├── HomeView.swift              画面A: ホーム
│   ├── EditorView.swift            画面B: エディタ
│   ├── LayoutCarousel.swift        レイアウト候補カルーセル+キャンバス描画
│   └── AdjustPanel.swift           余白・色・比率の調整パネル
├── Rendering/
│   ├── CollageRenderer.swift       プレビュー解像度の合成
│   └── ExportRenderer.swift        フォトライブラリ書き出し(Phase 2 でフル解像度化)
└── Store/PresetStore.swift         JSON 永続化(StoreKit 2 は Phase 3)
```
