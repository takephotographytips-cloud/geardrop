# Codex への引き継ぎサマリー

このファイルは「引き継ぎ時の一枚もの」です。詳細は各リンク先を参照してください。

## 1. 何を引き継ぐか

iOS アプリ「**Stack - 余白コラージュ**」の開発と App Store リリース。
写真(1〜6枚)を美しい余白で1枚の作品にする、3タップ完結のコラージュアプリ。
コードは機能完成済み、**App Store 提出の直前**。

## 2. 最初にやること

1. `AGENTS.md`(リポジトリ直下)を読む — ルールと入口
2. `CollageApp/docs/HANDOFF.md` を**全文**読む — 設計・不変条件・履歴・残タスク
3. `git log --oneline` で開発の流れを把握(下記「主要コミット」も参照)

## 3. リポジトリと環境

- リポジトリ: `takephotographytips-cloud/geardrop`
- **作業ブランチ: `claude/phase-1-implementation-0elq6w`**(main 未マージ・PR 未作成)
- アプリ本体は `CollageApp/`(Xcode プロジェクト)。リポジトリ直下は無関係な Next.js アプリ
- ビルド/テストはユーザーの Mac(Xcode 26)。エージェント環境では iOS ビルド不可 —
  数値ロジックは手元で検証してから XCTest に落とす運用

## 4. 完成しているもの

- **アプリ機能**: 3タップフロー / 縦・横レイアウト / セル内パン・ズーム / 写真入れ替え(長押しD&D) /
  比率5種 / 余白・間隔・背景色(スポイト付き) / フル解像度書き出し(16bit・P3・EXIF・HEIC/JPEG) /
  プリセット保存・復元 / 初回チュートリアル / **Stack Pro**(¥980買い切り: プリセット無制限 +
  デザインフレーム4種+グレイン + 水平/回転補正)
- **提出素材**(すべて `CollageApp/AppStore/`): アイコン / メタデータ / 実機QAリスト /
  スクショ生成スクリプト+撮影済み5枚 / 公開済みプライバシー・サポートサイト

## 5. 残っているのは App Store Connect 手作業だけ

`CollageApp/AppStore/release_checklist.md` の手順。特に:
- Xcode で In-App Purchase capability 追加
- ASC で IAP `com.dstudio.collageapp.pro`(¥980)を登録し「初回バージョンと一緒に審査提出」にチェック
- Archive → アップロード → メタデータ入力 → 提出

エージェントの次の出番: **実機QAのバグ修正 / 審査リジェクト対応 / 機能追加**。

## 6. 主要コミット(新しい順・抜粋)

- チュートリアル(Coach Marks)+ 写真入れ替え + 調整ボタン化
- 水平・回転補正(Pro)
- Stack Pro 単一課金化(旧: パック3種を廃止)/ デザインフレーム4種+グレイン
- Phase 4 リリース準備(アイコン・素材)
- Phase 3 プリセット+StoreKit+セッション復元
- Phase 2 フル解像度書き出し
- Instagram/Canva 型編集への刷新(均等セル+セル内変形)
- Phase 1 初期実装

## 7. 絶対に守る不変条件(詳細は HANDOFF セクション3)

プレビュー=書き出しの一致 / CanvasSpec の後方互換(init(from:)) / 写真非破壊 /
外部依存ゼロ / 座標系(ExportRenderer は左上原点に反転済み) / メモリ(1枚ずつ順次デコード)。
