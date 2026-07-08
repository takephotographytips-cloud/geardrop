# Stack (CollageApp) 引き継ぎ書

どのセッション・どのモデルでも、これを読めば同じ精度で開発を継続できることを目的とした文書。
最終更新: 2026-07-05(Phase 4 まで完了時点)

---

## 1. プロダクト定義

**写真(1〜6枚)を美しい余白で1枚の"作品"にする、3タップ完結のコラージュアプリ。**

- ターゲット: カメラ愛好家・フォトグラファー(Inset ユーザーと同一クラスタ)
- 差別化: ①デフォルトで美しい(テンプレを探させない) ②書き出し画質(16bit・P3・EXIF)
  ③買い切りのみ・サブスクなし ④データ収集ゼロ
- 参照アプリ: Inset(単写真フレーム)、Instagram/Canva(セル内編集の操作感)
- 設計原則: **引き算**。機能を足すときは常に「世界観がブレないか」を疑う。
  フィルター・色編集・テキスト・ステッカーは非スコープ(仕様書セクション5)

### 発注者

D-STUDIO ダイヤ監督。日本語でやりとり。**リリースを急いでいる**。
判断は速く、提案は「推奨案+理由」を1つ出す形が好まれる。仕様変更の要望は
参考画像(競合アプリのスクショ)付きで来ることが多い。

## 2. 現在の状態(2026-07-05)

- ブランチ: `claude/phase-1-implementation-0elq6w`(全作業ここ。main 未マージ)
- Phase 1〜3 完了、Phase 4(リリース準備)はコード側完了・ユーザーの手作業待ち
- ユーザーは Mac + Xcode 26 で動作確認済み。シミュレータでテスト購入まで確認済み
- 次のイベント: Apple Developer Program 加入 → App Store Connect 登録 → 審査提出

### フェーズ履歴と主要な設計変更

| 時期 | 内容 |
|---|---|
| Phase 1 | 仕様書 v1.0 どおり実装(6レイアウト・アスペクトフィット・トリミングなし) |
| **v1.1 仕様変更** | ユーザー要望で Instagram/Canva 型へ全面変更: レイアウトは縦/横の**均等分割2種**のみ、写真は**カバーフィット+セル内ドラッグ/ピンチ**(CellTransform)。スワイプカルーセルはジェスチャー競合のため**セグメント切替に置換** |
| Phase 2 | フル解像度書き出し(16bit/P3/EXIF)、スポイト付きカラーピッカー、ガタースライダー、設定画面 |
| Phase 3 | プリセット保存/呼出、セッション復元、課金(当初はパック3種×¥480) |
| **課金モデル v2** | ユーザー判断で単一の「**Stack Pro**」¥980 買い切りに変更。①プリセット無料3つ制限 ②デザインフレーム4種(フィルム/イエロー/シネマ/プリント)+グレイン |
| センター廃止 | 一度追加した「センターフォーカス」レイアウトはユーザー判断で**廃止**(最初のコンセプト=縦・横の2パターンのみに戻す)。レイアウトは常に `[.verticalStack, .horizontalRow]` |
| Pro 拡張2 | **水平・回転補正**(Pro 限定)。`CellTransform.rotationDegrees` を有効化(90°単位 `quarterTurnsDegrees` + 微調整 `fineAngleDegrees` の合成、`normalizedDegrees` で (-180,180] に正規化)。カバー計算は回転対応: needW = W\|cosθ\|+H\|sinθ\| 等(θ=0 で旧式と一致)、オフセットは写真ローカル軸 (u,v) に射影してクランプ(Python 照合済み)。UI: 写真タップ → `selectedPhotoID` → PhotoAdjustPanel(±15°スライダー/90°回転/リセット)+ CellSelectionOverlay(三分割グリッド)。描画: プレビューは rotationEffect、書き出しは矩形中心軸の CGContext 回転(ExportRenderer では反転打ち消しの**前**に適用) |
| Phase 4 | アイコン生成、リリース設定、App Store 素材ドラフト(`AppStore/`) |

## 3. アーキテクチャと不変条件

### ファイルマップ(役割つき)

```
CollageApp/CollageApp/
├── App/CollageApp.swift          @main。HomeView を出すだけ
├── Models/                       ← 純粋ロジック。UIKit/SwiftUI を import しない(CGだけ)
│   ├── CollageLayout.swift       縦/横の均等分割セル計算。margin→frame帯→gutter の順で内側へ
│   ├── CellTransform.swift       セル内変形(scale/offset/rotation将来用) + CellGeometry(カバーフィット矩形+クランプ)
│   ├── FrameStyle.swift          デザインフレーム。BandContext で縦横対称に幾何を生成 → [FrameElement]
│   ├── CanvasSpec.swift          比率/余白/間隔/背景色/フレーム。★カスタム init(from:) で後方互換
│   └── Preset.swift              Codable プリセット
├── ViewModels/EditorViewModel.swift  @Observable @MainActor。写真(プレビュー+元Data)、
│                                 transforms[UUID:CellTransform]、Undo/Redo、セッション保存/復元
├── Views/
│   ├── HomeView.swift            ピッカー自動表示(セッションある時は抑制)、プリセットチップ、再開ボタン
│   ├── EditorView.swift          キャンバス+レイアウト切替+AdjustPanel。しおり=プリセット保存(3個制限ゲート)
│   ├── CollageCanvas.swift       セルのジェスチャー処理 + FrameDecorationCanvas(装飾+グレインのプレビュー)
│   ├── AdjustPanel.swift         余白/間隔/色(スポイト=標準ColorPicker)/比率/フレーム(🔒はペイウォールへ)
│   ├── ProPaywallView.swift      Stack Pro ペイウォール
│   └── SettingsView.swift        書き出し形式/EXIF/Pro導線/復元/バージョン
├── Rendering/
│   ├── CollageRenderer.swift     プレビュー解像度合成 + FrameElementRenderer(CG描画+drawGrain) + GrainTexture
│   └── ExportRenderer.swift      フル解像度書き出し(下記「書き出しパイプライン」参照)
└── Store/
    ├── PresetStore.swift         プリセットJSON + StoreKit 2(Pro単一商品)
    └── SessionStore.swift        編集状態の保存/復元(Application Support/EditSession)
```

### 壊してはいけない不変条件

1. **プレビュー=書き出し**: 写真の配置は `CellGeometry.imageRect`、フレームは
   `FrameStyle.decorationElements` → `[FrameElement]` を両側(SwiftUI Canvas / CGContext)が描く。
   グレインは `GrainTexture.shared`(シード固定)+タイルサイズ=短辺/8 で両側一致。
   **片側だけに描画コードを足してはいけない**
2. **座標系**: ExportRenderer の CGContext は生成直後に `translateBy(0,H); scaleBy(1,-1)` で
   **左上原点に反転済み**。以後の矩形・UIKit テキスト描画はそのまま使える。
   写真の描画だけは内部でさらに反転を打ち消している(`draw(_:orientation:in:context:)`)。触るとき注意
3. **CanvasSpec の後方互換**: フィールド追加時は必ず `init(from:)` に
   `decodeIfPresent ?? デフォルト` を追加。ユーザー端末の保存済みプリセット/セッションが壊れる
4. **transforms は写真の UUID キー・オフセットはセル寸法で正規化**。
   これによりレイアウト変更/比率変更後も位置・ズームが引き継がれ、`CellGeometry.clamped` が
   「背景が見えない範囲」に自動補正する
5. **メモリ**: 書き出しは1枚ずつ順次デコード(autoreleasepool)。6枚同時フル展開は禁止。
   出力長辺は `requiredLongSide`(どの写真も元解像度を超えない)+上限 8bit:8192 / 16bit:5120
6. **写真そのものは不変**: 元 Data を保持し、変形はすべて描画時に適用
7. **外部依存ゼロ・画像アセット極小**(アイコンのみ)。フレームもグレインもプログラム生成

### 書き出しパイプライン(ExportRenderer)— 差別化の核

- ソース情報は ImageIO プロパティから取得(デコードせず): pixel size / orientation / depth / profile
- **depth > 8 の素材が1枚でもあれば 16bit コンテキスト**(バンディング対策)。
  16bit 時は `CGImageSourceCreateImageAtIndex` でフルデコード(**thumbnail API は 8bit に落ちるので使わない**)
  → EXIF 回転は描画時に手動適用。8bit 時は thumbnail API(回転適用済み・省メモリ)
- P3 素材があれば Display P3、なければ sRGB
- EXIF: 設定 ON なら1枚目の Exif/TIFF 辞書をコピー(TIFF の Orientation は除去)
- HEIC(品質0.9)/ JPEG(1.0)→ `PHAssetCreationRequest.addResource(data:)` で保存
  (UIImage 経由だとメタデータが落ちるため Data で追加している)

### StoreKit 2

- 商品は1つ: `com.dstudio.collageapp.pro` 非消耗型 ¥980
- `PresetStore` が管理: `Transaction.currentEntitlements` で復元、`Transaction.updates` 常駐リスナー、
  検証済み(verified)のみ反映、revocationDate で剥奪対応
- ローカルテスト: `CollageApp/Products.storekit` をスキームに紐付け済み。
  **パスは `../../Products.storekit`**(過去に `../../../` で間違えて商品取得エラーになった。
  症状=「ストア情報を取得できませんでした」。手動修正: Edit Scheme → Run → Options → StoreKit Configuration)
- **Bundle ID を変えたら productID(コード内 `PresetStore.proProductID` と Products.storekit)も揃える**

## 4. 開発環境の制約と作法

- **この実行環境は Linux コンテナ。Xcode / Swift / シミュレータは無い**
  - コードはコンパイル一発通過を目指して書く(ユーザーにエラーを貼ってもらい即修正のループ)
  - 数値計算(レイアウト/ジオメトリ)は **Python で同一アルゴリズムを書いて期待値を検証**してから
    テストに書く(過去全フェーズでこの方法。的中している)
  - ビルド/テスト確認はユーザーの Mac(`git pull` → ⌘R / ⌘U)。または GitHub Actions の
    手動ワークフロー `iOS Build & Test`(macOS ランナー課金のため手動のみ)
- **Xcode プロジェクトは objectVersion 77 / filesystem-synchronized groups**:
  `CollageApp/CollageApp/` と `CollageAppTests/` 配下に**ファイルを置くだけで自動的にターゲットに入る**。
  pbxproj の編集はビルド設定変更時のみ(ID は 1A2B3C4D... の連番)
- テストは XCTest(`@testable import CollageApp`)。実行できないぶん、
  不変条件テスト(全レイアウト×全比率×全枚数のループ)を厚めに書く
- git: 機能単位で日本語コミットメッセージは英語(既存スタイル参照 `git log`)。
  コミット後すぐ `git push -u origin claude/phase-1-implementation-0elq6w`

### ユーザーへの報告フォーマット(毎回)

1. 何を実装したか(仕様との対応)
2. `git pull` → ⌘R の指示
3. **確認ポイントの箇条書き**(番号付き、具体的な操作手順)
4. 注意点(あれば)と次の選択肢

## 5. 既知のハマりどころ

| 事象 | 対処 |
|---|---|
| SwiftUI の `Text(_:format:)` に CGFloat | `Double()` に変換しないと `.percent` が型解決しない |
| CGImageSource thumbnail API | 16bit を保持しない。深度維持は CreateImageAtIndex+手動回転 |
| PhotosPicker の選択順 | `selectionBehavior: .ordered` 必須(選んだ順=配置順) |
| TabView ページング×セル内ドラッグ | 競合する。だからレイアウト切替はセグメント(復活させない) |
| スキームの StoreKit パス | `../../Products.storekit`(xcshareddata 基準の相対) |
| deinit で Task キャンセル | @MainActor クラスで警告になるため PresetStore はあえて deinit なし(アプリ生存期間シングルトン的) |
| Undo スタック | カラーピッカー連続変更で肥大化 → 100 件でトリム済み |
| シミュレータのピンチ | Option+ドラッグ(ユーザーは知っている) |

## 6. 残タスク

### 審査提出まで(ユーザー主導、サポートする)
- [ ] Apple Developer 加入 → `AppStore/release_checklist.md` の手順1〜6
- [ ] 実機での最終確認(特に: 16bit 書き出しのバンディング検証は α7V の実写 HEIF で)
- [ ] スクリーンショット撮影(構成案は checklist 内。キャッチコピー詰めを頼まれる可能性大)
- [ ] プライバシーポリシーの公開(文面は `AppStore/metadata_ja.md` に用意済み)

### 審査中/後(想定される依頼)
- リジェクト対応(`.claude/skills/collage-release/SKILL.md` にプレイブック)
- バグ修正 → バージョニング: hotfix は `CURRENT_PROJECT_VERSION` +1、機能追加は `MARKETING_VERSION` を上げる(pbxproj 内、Debug/Release 両方)
- 「前回の編集を再開」まわりは実機での長期利用で初めて出る不具合がありがち(容量・権限)

### Phase 5 候補(仕様書とレビュー要望より)
- フレーム部への EXIF 文字入れ(撮影情報をフレームに焼く。Inset レビューで要望多)
- フレームの調整パラメータ(グレイン強度スライダー等)
- 新フレームの追加(ポラロイド風など。FrameStyle に case 追加+BandContext で幾何生成のパターン確立済み)
- プリセットのサムネイル表示(CollageRenderer が使える)

## 7. 重要ファイルへのポインタ

- 仕様書 v1.0: `CollageApp/collage_app_spec_for_claude_code.md`
- 実装状況: `CollageApp/README.md`
- 提出素材: `CollageApp/AppStore/metadata_ja.md`
- リリース手順: `CollageApp/AppStore/release_checklist.md`
- CI: `.github/workflows/ios-build-test.yml`(手動実行のみ)
