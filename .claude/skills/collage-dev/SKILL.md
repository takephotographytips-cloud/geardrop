---
name: collage-dev
description: CollageApp (iOS コラージュアプリ Stack) の機能追加・修正・改善のワークフロー。Swift コードを変更する前に必ずこの手順に従う。バグ修正、新機能、フレーム追加、UI 変更、リファクタリングすべてに適用。
---

# CollageApp 開発ワークフロー

## 前提(毎回)

1. `CollageApp/docs/HANDOFF.md` を読む(未読なら)。特に「不変条件」と「ハマりどころ」
2. 現在のブランチが `claude/phase-1-implementation-0elq6w` であることを確認
3. **この環境ではビルドできない**(Linux・Xcode なし)。コンパイルエラーはユーザーの Mac で発覚する。
   一発で通るコードを書くため、変更前に関連ファイルを Read して既存のパターン・命名に合わせる

## 実装手順

### 1. 影響範囲の特定

変更が以下に触れるか確認し、触れるなら**両側セット**で変更する:

- 矩形・配置計算 → `CollageLayout` / `CellGeometry`(プレビューと書き出しが共有。片側変更禁止)
- フレーム描画 → `FrameStyle.decorationElements`(FrameElement を生成) +
  描画は `FrameDecorationCanvas`(プレビュー)と `FrameElementRenderer`(書き出し)が既に共通処理。
  **新しい FrameElement ケースを足すときだけ両方の switch を更新**
- `CanvasSpec` へのフィールド追加 → `init(from:)` に `decodeIfPresent ?? デフォルト` を必ず追加
  (後方互換)。テスト `testCanvasSpecDecoding_withoutFrameKey...` に倣い互換テストも追加

### 2. 数値検証(計算ロジックを触った場合は必須)

テストの期待値を書く前に、**Python で同じアルゴリズムを実装して数値を出す**:

```bash
python3 << 'EOF'
# アルゴリズムを複製して期待値を計算
EOF
```

出た値をテストにハードコードする(accuracy 0.001)。過去の全フェーズでこの方法を使い、
ユーザーの Mac で全テストが一発グリーンになっている。

### 3. ファイル配置

- `CollageApp/CollageApp/` と `CollageApp/CollageAppTests/` 配下は synchronized group:
  **ファイルを作成/削除するだけでターゲットに自動反映**。pbxproj 編集不要
- Models/ は SwiftUI/UIKit を import しない(CoreGraphics まで)。UI 変換は Views/ 側の extension
- ビルド設定の変更だけ pbxproj を編集(Debug/Release 両方に同じ変更)

### 4. テスト

- XCTest。新ロジックには不変条件テスト(全レイアウト×全比率×全枚数ループのパターンが
  `CollageLayoutTests` / `ProFeatureTests` にある)を追加
- Codable モデルを変えたらラウンドトリップテスト

### 5. 完了処理

1. 旧 API の残存参照を Grep で確認(`Grep pattern: "削除したシンボル名"`)
2. `CollageApp/README.md` の実装状況を更新
3. コミット(英語・既存スタイル)→ `git push -u origin claude/phase-1-implementation-0elq6w`
4. ユーザーへ日本語で報告:
   - 実装内容の要約
   - `git pull` → ⌘R(または ⌘U)の指示
   - **番号付きの確認ポイント**(具体的な画面操作)
   - コンパイルエラーが出たら貼ってもらうよう添える(初回変更が大きいとき)

## バージョニング(リリース後の変更)

- バグ修正のみ: pbxproj の `CURRENT_PROJECT_VERSION` を +1(Debug/Release/テストターゲット全部)
- 機能追加: `MARKETING_VERSION` を上げる(例 1.0 → 1.1)+ CURRENT_PROJECT_VERSION +1

## してはいけないこと

- 写真データの加工(変形は描画時のみ)
- SPM 依存の追加、画像アセットの追加(プログラム描画が原則)
- スワイプでのレイアウト切替の復活(セル内ドラッグと競合する)
- サブスクリプションの導入(買い切りのみが訴求点)
- フィルター・色編集・テキスト・ステッカー機能(非スコープ。ただしフレームへの EXIF 文字入れは Phase 5 候補)
