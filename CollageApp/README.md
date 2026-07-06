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

### Phase 2: 品質 ✅(このコミット)
- [x] ExportRenderer フル解像度化(差別化の核)
  - 元画像を CGContext で1枚ずつ順次デコード・合成(メモリ対策)
  - 10bit 以上の素材があれば 16bit コンテキストで合成(バンディング防止)
  - Display P3 素材があれば P3 のまま合成(カラースペース維持)
  - 出力長辺は「どの写真も元解像度を超えない」値を自動計算(8bit: 最大8192px / 16bit: 最大5120px)
  - 1枚目の EXIF(撮影日時・カメラ・レンズ)を書き出しにコピー(設定で ON/OFF)
  - HEIC(デフォルト)/ JPEG 最高画質(設定で切替)
- [x] 背景色: プリセット3色 + カラーピッカー(スポイト内蔵、写真から色を拾える)
- [x] 間隔(ガター)スライダー 0〜10%
- [x] 設定画面(ホームのギアアイコン: 書き出し形式・EXIF 保持のみの最小構成)
- [x] 出力解像度計算のユニットテスト

### Phase 3: プリセット+課金 ✅
- [x] プリセット保存/呼び出し
  - エディタ右上のしおりボタンで現在の設定(レイアウト・比率・余白・間隔・色・フレーム)を名前付き保存
  - ホーム下部に一覧表示 → タップでプリセット適用済みの状態で写真選択へ(Inset レビュー要望の先回り)
  - 長押しで削除
- [x] 編集途中の状態復元(アプリ再起動時)
  - 写真の元データ+設定・変形を Application Support に保存
  - ホームに「前回の編集を再開」ボタン(セッションがあるときは起動時の自動ピッカーを抑制)

### 課金モデル v2: Stack Pro ✅(このコミット)
単一の買い切り「**Stack Pro**」¥980(非消耗型、productID: `com.dstudio.collageapp.pro`)。
基本ツールで再現できる設定集ではなく、機能そのものを価値にする。

- [x] **プリセット無制限** — 無料版は3つまで保存可、4つ目からペイウォール表示
- [x] **センターフォーカスレイアウト** — 雑誌風の全幅レイアウト(横一列・中央が主役)
  - 左右はキャンバス端まで(横マージン0)、余白は写真間(=間隔スライダー)のみ、上下は余白設定を適用
  - 枚数別の重み配分: 1枚=全幅 / 2枚=50:50 / 3枚=22:56:22 / 4枚=16:34:34:16 /
    5枚=10:16:48:16:10 / 6枚=10:14:26:26:14:10(すべて左右対称・合計1)
  - レイアウト切替セグメントに「センター 🔒」として表示。未購入時はペイウォールへ
- [x] **デザインフレーム4種** — 画像アセットなしのプログラム描画(軽量・解像度非依存)
  - フィルム: 黒地+パーフォレーション+「STACK 400」銘柄・コマ番号
  - イエロー: 黒地+黄色い送り穴(両側)+縁印字風のコード数字
  - シネマ: 黒地+両側の送り穴+アンバーのコマ番号・送りマーカー(35mm シネフィルム風)
  - プリント: 紙白地+トンボ・ラベル
  - フィルム系3種にはグレイン(シード固定の生成ノイズをオーバーレイ合成)でオールド感を付与
  - フレームはレイアウトのセル計算に統合(帯ぶん内側へ)。プレビューと書き出しは同じ FrameElement を描画
- [x] Inset 風ペイウォール(ヒーロー+機能リスト+Lifetime 価格カード+復元)
- [x] 設定画面に Pro 導線(アップグレード・購入を復元・バージョン表記)
- [x] `Products.storekit` はローカルテスト用に Stack Pro 1商品(¥980)
- [x] 旧保存データとの後方互換(frame キーのないプリセット/セッションもデコード可)

### Phase 4: リリース準備 🚧(このコミット)
- [x] アプリアイコン(オフホワイト+縦積みモチーフ、プログラム生成 1024px)
- [x] 表示名 `Stack`・暗号化申告 `ITSAppUsesNonExemptEncryption = NO` を設定
- [x] App Store メタデータドラフト → `AppStore/metadata_ja.md`
  (アプリ名候補・説明文・キーワード・IAP 文言・プライバシーポリシー文面・審査メモ)
- [x] リリース手順書 → `AppStore/release_checklist.md`
  (署名 / IAP 登録 / スクリーンショット構成 / アーカイブ / 提出 / トラブルシューティング)
- [ ] あなたの手作業: Apple Developer 加入、App Store Connect 登録、スクリーンショット撮影、実機確認、提出

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
│   ├── FrameStyle.swift            デザインフレーム(帯・装飾要素のジオメトリ生成)
│   ├── CanvasSpec.swift            比率・余白・ガター・背景色
│   └── Preset.swift                Codable プリセット
├── ViewModels/EditorViewModel.swift  @Observable。セル変形・Undo/Redo スタック含む
├── Views/
│   ├── HomeView.swift              画面A: ホーム(ギア→設定)
│   ├── EditorView.swift            画面B: エディタ(レイアウト切替セグメント)
│   ├── CollageCanvas.swift         キャンバス+セル(ドラッグ/ピンチのジェスチャー処理)
│   ├── AdjustPanel.swift           余白・間隔・色・比率の調整パネル
│   ├── ProPaywallView.swift        Stack Pro ペイウォール(¥980 買い切り)
│   └── SettingsView.swift          設定(書き出し形式・EXIF 保持)
├── Rendering/
│   ├── CollageRenderer.swift       プレビュー解像度の合成(プリセットサムネイル等に使用予定)
│   └── ExportRenderer.swift        フル解像度書き出し(16bit・P3・EXIF・HEIC/JPEG)
└── Store/
    ├── PresetStore.swift           プリセット永続化 + StoreKit 2(パック課金)
    └── SessionStore.swift          編集途中の状態保存・復元
```
※ `Products.storekit`(プロジェクト直下)はシミュレータで課金をテストするための StoreKit Configuration。
スキームに紐付け済みだが、効かない場合は Product > Scheme > Edit Scheme... > Run > Options >
StoreKit Configuration で選び直す。
