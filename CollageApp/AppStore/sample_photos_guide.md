# サンプル写真ガイド(スクリーンショット用)

## 2段構え

1. **動作確認用(即席)**: `fetch_sample_photos.sh` を実行 → 風景12枚が自動でシミュレータに入る
2. **提出スクショ用(厳選)**: 以下の手順で Unsplash / Pexels から手動で選ぶ(見栄えが段違い)

## 厳選手順(Mac・15分)

1. Safari で [unsplash.com](https://unsplash.com) または [pexels.com](https://www.pexels.com) を開く
2. 下の検索ワードで探し、**Download(無料)**で保存(どちらも商用利用可・出典表記不要)
3. ダウンロードした写真を**シミュレータのウィンドウにドラッグ&ドロップ**するだけで
   写真アプリに追加される(または `xcrun simctl addmedia booted ~/Downloads/*.jpg`)

## おすすめ検索ワード

### シネマティック風景(スクショ1・3・4枚目向き)
- `iceland cinematic` — 荒涼とした絶景。フィルムフレームと相性抜群
- `dolomites` — ドロミテの山岳。縦位置が多い
- `kyoto night rain` — 夜の路地。シネマフレーム向き
- `faroe islands` — 曇天の崖と海。ムーディー
- `california coast film` — 海岸+フィルム調

### フィルム調・ノスタルジー(フレーム訴求のスクショ2枚目向き)
- `film photography street` / `35mm film look`
- `analog summer` — 粒子感のある夏の写真

### ポートレート(スクショに人物を入れる場合)
- Pexels で `portrait film` / `editorial portrait woman` / `golden hour portrait`
- **注意**: 人物写真はモデルリリース(肖像権の許諾)が保証されないため、
  **App Store のスクリーンショットには風景・物を推奨**。人物はテスト用にとどめるか、
  顔がはっきり写らない後ろ姿・シルエット系(検索: `woman back mountain`)を選ぶと安全

## 選定のコツ(統一感がスクショの質を決める)

- **1組=同系色の3〜4枚**で揃える(例: 青系=海・空・氷河 / 暖色系=夕景・街・肌)
- 縦位置(ポートレート向き)中心に。アプリの 4:5 キャンバス+縦積みと相性が良い
- 空や水面など**なだらかなグラデーションを含む写真**を1枚入れる
  → 16bit 書き出しの画質訴求(スクショ6枚目)に使える
- 極端に暗い写真は避ける(サムネイルで潰れる)

## シミュレータへの追加方法(まとめ)

| 方法 | 手順 |
|---|---|
| ドラッグ&ドロップ | Finder から写真を選んでシミュレータの画面へドロップ |
| コマンド | `xcrun simctl addmedia booted <ファイル...>` |
| スクリプト | `bash CollageApp/AppStore/fetch_sample_photos.sh`(風景12枚を自動投入) |
