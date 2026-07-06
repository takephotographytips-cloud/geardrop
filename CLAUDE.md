# geardrop リポジトリ

このリポジトリには2つの独立したプロジェクトがある:

1. **`CollageApp/`** — iOS 写真コラージュアプリ「Stack」(SwiftUI, iOS 17+)。**現在の主戦場**
2. リポジトリ直下 — Next.js の Web アプリ(geardrop)。CollageApp とは無関係

## CollageApp の作業を始める前に(必読)

**必ず `CollageApp/docs/HANDOFF.md` を読むこと。** プロダクト定義・設計判断の履歴・
壊してはいけない不変条件・環境の制約・残タスクがすべて書いてある。
仕様書は `CollageApp/collage_app_spec_for_claude_code.md`(v1.0。その後の変更は HANDOFF に記載)。

### 絶対ルール(要約)

- **この環境は Linux で Xcode/Swift が無い**。ビルド・テスト実行はできない。
  レイアウト計算などの数値は Python でアルゴリズムを複製して検証してからテスト期待値にする。
  ビルド確認はユーザーが Mac で行う(`git pull` → ⌘R)。コードは一発でコンパイルが通る精度で書く
- **ブランチは `claude/phase-1-implementation-0elq6w`**。機能単位でコミットし、毎回プッシュする
- **プレビューと書き出しの見た目は必ず一致させる**。矩形計算は `CellGeometry`、
  フレーム装飾は `FrameElement` 経由。片側だけ変更してはならない
- **`CanvasSpec` にフィールドを追加するときは `init(from:)` に `decodeIfPresent` + デフォルト値を必ず追加**
  (保存済みプリセット/セッションとの後方互換が壊れる)
- **写真は絶対にトリミング加工しない**(セル内カバーフィット+クリップのみ。元データは不変)
- 外部依存(SPM)はゼロを維持。画像アセットも極力使わない(プログラム描画)
- ユーザーとのやりとりは日本語。作業完了時は「`git pull` → ⌘R → 確認ポイント箇条書き」の形式で伝える

### プロジェクト固有スキル

- 機能追加・修正: `.claude/skills/collage-dev/SKILL.md` の手順に従う
- リリース・審査対応: `.claude/skills/collage-release/SKILL.md` の手順に従う
