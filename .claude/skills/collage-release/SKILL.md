---
name: collage-release
description: CollageApp (Stack) の App Store リリース・審査対応・運用のワークフロー。審査提出のサポート、リジェクト対応、リリース後のホットフィックス、バージョンアップ、IAP トラブル対応に適用。
---

# CollageApp リリース・審査・運用ワークフロー

## 前提

- 手順書: `CollageApp/AppStore/release_checklist.md`(App Store Connect の全手順)
- 提出素材: `CollageApp/AppStore/metadata_ja.md`(説明文・キーワード・IAP 文言・プライバシー文面)
- App Store Connect の操作はユーザーしかできない。**こちらの役割は「次にやる手順の具体的な案内」と
  「コード側で必要な変更」**。ユーザーは初リリースなので、専門用語は噛み砕いて伝える

## 審査提出サポート

ユーザーから進捗報告が来たら checklist の該当ステップを特定し、次の1〜2手だけを具体的に案内する
(全部を一度に投げない)。特に落としやすい点:

1. **IAP「最初のAppバージョンと一緒に審査に提出」チェック**(初回リジェクトの定番)
2. In-App Purchase capability の追加(Xcode 側)
3. Bundle ID を変更した場合 → `PresetStore.proProductID` と `Products.storekit` の productID を
   同期変更してコミット(コード側作業。忘れると本番で購入不能)
4. プライバシーは「データを収集しない」で申告(分析・広告 SDK ゼロ、通信は StoreKit のみ)
5. 暗号化申告は設定済み(`ITSAppUsesNonExemptEncryption = NO`)

## リジェクト対応プレイブック

リジェクト文面を貼ってもらい、Guideline 番号で分類して対応:

| Guideline | 典型内容 | 対応 |
|---|---|---|
| 2.1 (App Completeness) | IAP が動かない/見つからない | ASC で IAP のステータス確認。「審査に提出」漏れ→再提出。レビュー環境での StoreKit 障害なら Resolution Center で丁寧に再審査依頼 |
| 3.1.1 (In-App Purchase) | 復元ボタンがない等 | 実装済み(ペイウォール・設定の両方)。場所をスクショで回答 |
| 3.1.2 | 課金内容の説明不足 | ペイウォールの文言強化で対応(ProPaywallView) |
| 5.1.1 (Privacy) | 権限の説明文・ポリシー URL | `NSPhotoLibraryAddUsageDescription` は設定済み。ポリシー URL の掲示を確認 |
| 4.3 (Spam/類似) | コラージュアプリは既にある | 差別化点(16bit 書き出し・EXIF 保持・買い切り・データ収集ゼロ)を Resolution Center で主張。metadata_ja.md の訴求点を流用 |
| 2.3 (Metadata) | スクショが実 UI でない等 | 実 UI スクショで撮り直し案内 |

回答文はユーザーに代わって日本語でドラフトし、必要なら英語版も用意する
(Resolution Center は英語のほうが往復が速い)。

## リリース後の運用

### ホットフィックス手順

1. バグ修正(collage-dev スキルの手順で)
2. pbxproj の `CURRENT_PROJECT_VERSION` を +1(app/tests の Debug/Release 全部)
3. ユーザーに案内: Archive → Distribute → ASC で新ビルド選択 → 「審査へ提出」
   (審査は初回より速い。緊急なら「App Review を優先」リクエストも案内)

### 機能アップデート

- `MARKETING_VERSION` を上げる(1.0 → 1.1)
- ASC 側は「+ バージョン」で新バージョン作成 → What's New(日本語)をドラフトしてあげる

### レビュー(App Store 評価)対応

- 成功指標: 評価4.5以上/購入率 DL の3〜5%(仕様書セクション7)
- 機能要望レビューは Phase 5 候補(HANDOFF.md セクション6)と突き合わせて優先度提案

### よくある本番トラブル

| 症状 | 原因と対処 |
|---|---|
| 実機で価格が「¥980」固定表示(placeholder) | ASC の IAP が「送信準備完了」でない or Paid Apps 契約未同意(Agreements, Tax, and Banking) |
| TestFlight で購入できない | Sandbox アカウントでサインインが必要。設定 → App Store → サンドボックスアカウント |
| 購入したのに Pro にならない | 「購入を復元」を案内(AppStore.sync → entitlements 再取得)。直らなければ Transaction.currentEntitlements 周りを調査 |
| 書き出しでメモリクラッシュ報告 | ExportRenderer の上限(8bit:8192/16bit:5120)を下げる。HANDOFF.md の「書き出しパイプライン」参照 |
