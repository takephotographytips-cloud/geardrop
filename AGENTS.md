# AGENTS.md — geardrop リポジトリ

このファイルは AI エージェント(Codex / Claude / 他)向けの入口です。**作業前に必ず読んでください。**

## このリポジトリには独立した2プロジェクトがある

1. **`CollageApp/`** — iOS 写真コラージュアプリ「**Stack - 余白コラージュ**」(SwiftUI, iOS 17+)。
   **現在アクティブな開発対象。** App Store 提出直前。
2. リポジトリ直下(`src/`, `next.config.ts` 等)— Next.js の Web アプリ(geardrop)。
   CollageApp とは無関係。触るのは明示的に指示されたときだけ。

以下、特記なき限り **CollageApp の話**です。

## 最初に読むべきもの(順番厳守)

1. **`CollageApp/docs/HANDOFF.md`** — プロダクト定義・設計判断の全履歴・**壊してはいけない不変条件**・
   アーキテクチャ・書き出しパイプライン・既知のハマりどころ・残タスク。**これが最重要。全文必読。**
2. `CollageApp/README.md` — 実装状況(フェーズ別チェックリスト)
3. `CollageApp/collage_app_spec_for_claude_code.md` — 元の仕様書 v1.0(以後の変更は HANDOFF に記載)

## 絶対に守るルール(要約。詳細は HANDOFF)

- **作業ブランチは `claude/phase-1-implementation-0elq6w` のみ。** main へ直接コミット/プッシュしない。
  PR はユーザーが明示的に頼むまで作らない。機能単位でコミットし、都度プッシュする。
  コミットメッセージは英語(既存 `git log` のスタイルに合わせる)。
- **この開発環境では iOS アプリをビルド/テストできない**(Xcode/Swift/シミュレータなし)。
  レイアウト・ジオメトリなど数値ロジックは、コードを書く前に手元(Python 等)で同一計算して
  期待値を検証し、それを XCTest に落とす。ビルド確認はユーザーが Mac で `git pull` → ⌘R / ⌘U で行う。
  **一発でコンパイルが通る精度**でコードを書く。
- **プレビューと書き出しの見た目は必ず一致させる。** 写真配置は `CellGeometry`、フレーム装飾は
  `FrameStyle.decorationElements` → `[FrameElement]` を SwiftUI 側と CGContext 側の両方が描く。
  片側だけ描画コードを足さない。
- **`CanvasSpec` にフィールドを追加するときは `init(from:)` に `decodeIfPresent ?? デフォルト` を必ず追加**
  (ユーザー端末の保存済みプリセット/セッションとの後方互換が壊れる)。
- **写真は非破壊**。元 Data を保持し、変形(移動/拡大/回転)はすべて描画時に適用。トリミング加工しない。
- **外部依存(SPM)ゼロ・画像アセット最小(アイコンのみ)** を維持。フレームもグレインもプログラム描画。
- ユーザーとのやりとりは**日本語**。作業完了時は「`git pull` → ⌘R → 番号付きの確認ポイント」の形式で報告。

## いまの状況(2026-07-06)

- アプリのコード・App Store 提出素材(アイコン/メタデータ/公開サイト/スクショ5枚)は**すべて完成**。
- 残りは **App Store Connect 上のユーザー手作業**(署名・IAP登録・アーカイブ・提出)。
  詳細と落としやすい点は `CollageApp/AppStore/release_checklist.md` と HANDOFF セクション6。
- エージェントの次の出番は「実機QAで出たバグ修正」「審査リジェクト対応」「新機能の追加」。

## リリース関連の資料の場所

すべて `CollageApp/AppStore/` 配下:
- `metadata_ja.md` … アプリ名/説明文/キーワード/IAP文言/審査メモ(コピペ用)
- `release_checklist.md` … 提出手順(署名〜提出)
- `device_qa_checklist.md` … 実機QAチェックリスト
- `make_screenshots.py` … スクショにコピーを合成(1320×2868 出力)
- `fetch_sample_photos.sh` … シミュレータへサンプル写真投入
- `privacy_policy.html` / `support.html` / `index.html` … 公開サイトの元ファイル
