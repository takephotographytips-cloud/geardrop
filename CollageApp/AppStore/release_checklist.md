# リリースチェックリスト(Phase 4)

コード側の準備は完了済み。以下は **Mac + App Store Connect であなたが行う手作業**の手順書。
所要時間の目安: 初回 2〜4時間(Apple の審査は別途1〜3日)。

## 0. 前提

- [ ] Apple Developer Program に加入済み(年間 ¥12,800)
- [ ] App Store で「Stack」の名前競合を確認 → `metadata_ja.md` の候補から決定

## 1. Xcode でのアプリ設定(15分)

- [ ] プロジェクト設定 → CollageApp ターゲット → **Signing & Capabilities**
  - Team: 自分のチームを選択
  - Bundle Identifier: `com.dstudio.collageapp` のままか、自分のドメインに変更
    (**変更した場合は `PresetStore.proProductID` と `Products.storekit` の productID も合わせて変更**)
- [ ] **Capability「In-App Purchase」を追加**(+ Capability ボタンから)
- [ ] 実機で最終動作確認(3タップフロー / フレーム / 保存画質 / 復元)

## 2. App Store Connect: アプリ登録(30分)

- [ ] [App Store Connect](https://appstoreconnect.apple.com) → マイApp → 「+」→ 新規App
  - プラットフォーム: iOS / 名前: 決定したアプリ名 / プライマリ言語: 日本語
  - Bundle ID: Xcode と同じもの / SKU: `collageapp-001` など任意
- [ ] App 情報: カテゴリ(写真/ビデオ)、年齢制限(4+)
- [ ] 価格: 無料

## 3. App Store Connect: App内課金(20分)

- [ ] マイApp → 対象App → 「App内課金」→「+」
  - 種類: **非消耗型**
  - 製品ID: `com.dstudio.collageapp.pro`(Bundle ID を変えた場合は合わせる)
  - 参照名/表示名/説明: `metadata_ja.md` 参照
  - 価格: ¥980
- [ ] 審査用スクリーンショット: ペイウォール画面のスクショをアップロード
- [ ] **App内課金を「最初のAppバージョンと一緒に審査に提出」にチェック**(重要)

## 4. スクリーンショット(1〜2時間)

必須: 6.9インチ(iPhone 16 Pro Max: 1320×2868)。6.5インチ用は自動流用可。
シミュレータで ⌘S で撮影できる。Inset と同様「実UIをそのまま見せる」構成を推奨:

1. エディタ画面(縦2枚+オフホワイト余白) — 「3タップで、作品になる」
2. フレーム: フィルムネガ適用 — 「フィルムの質感を、そのまま」
3. フレーム: イエローネガ適用
4. 調整パネル(色スポイト使用中) — 「余白も、色も、思いのまま」
5. ホーム(プリセット一覧) — 「お気に入りの設定を保存」
6. 書き出し品質訴求(拡大比較) — 「フル解像度・16bit処理」

文字入れは Keynote / Figma で。背景は #F5F2ED に統一するとフィードが揃う。

## 5. ビルドのアップロード(15分)

- [ ] Xcode: 実行先を **Any iOS Device (arm64)** にする
- [ ] Product → **Archive**
- [ ] Organizer が開いたら **Distribute App** → App Store Connect → Upload
- [ ] App Store Connect の「ビルド」欄に反映されるまで待つ(〜30分)

## 6. 提出(30分)

- [ ] `metadata_ja.md` から各欄をコピペ(説明文・キーワード・サブタイトル・プロモテキスト)
- [ ] スクリーンショットをアップロード
- [ ] **App プライバシー: 「データを収集しない」で申告**
- [ ] プライバシーポリシー URL(`metadata_ja.md` の文面例を公開したもの)
- [ ] 審査メモに `metadata_ja.md` の文面をコピペ
- [ ] ビルドを選択 → **審査へ提出**

## 7. 提出後

- [ ] 審査ステータスはメールで通知(通常1〜3日)
- [ ] リジェクト時は理由を読んで個別対応(IAP関連が最頻。3のチェック漏れに注意)
- [ ] 承認後: 手動リリース or 自動リリースを選択

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| Archive がグレーアウト | 実行先が シミュレータになっている → Any iOS Device に変更 |
| IAP が審査で「見つからない」 | 手順3の「一緒に審査に提出」チェック漏れ。IAP を提出し直す |
| 実機で価格が出ない | ASC の IAP が「送信準備完了」になっているか・Paid Apps 契約(Agreements)が有効か確認 |
| ITSAppUsesNonExemptEncryption を聞かれる | 設定済み(NO)。ダイアログが出た場合は「いいえ(標準暗号化のみ)」を選択 |
