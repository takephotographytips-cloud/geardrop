#!/bin/bash
# シミュレータに高解像度のサンプル風景写真を一括投入するスクリプト(Mac で実行)
#
# 使い方:
#   1. シミュレータを起動しておく(⌘R でアプリを実行した状態でOK)
#   2. ターミナルで: bash CollageApp/AppStore/fetch_sample_photos.sh
#
# 写真は Lorem Picsum (https://picsum.photos) 経由の実写素材(無料・出典表記不要)。
# テスト・動作確認用。App Store 提出用の最終スクショには
# sample_photos_guide.md の手順で厳選した写真を使うこと。

set -u
DEST="$HOME/Downloads/stack-sample-photos"
mkdir -p "$DEST"

# ID: Picsum の安定ID(風景・自然・シネマティック寄りを選定)
# サイズ: 縦位置 3000x3750 (4:5) / 横位置 4000x2667 (3:2) を混在
PHOTOS=(
  "1015 3000 3750"   # 渓谷と川
  "1016 4000 2667"   # 岩山
  "1018 3000 3750"   # 山と湖
  "1019 4000 2667"   # 湖と夕景
  "1022 4000 2667"   # オーロラ
  "1036 3000 3750"   # 雪山
  "1039 3000 3750"   # 滝
  "1043 3000 3750"   # 夜の街灯
  "1044 4000 2667"   # 月夜
  "1080 3000 3000"   # 静物
  "110  4000 2667"   # 海岸
  "1050 3000 3750"   # 建築
)

echo "→ ダウンロード先: $DEST"
count=0
for entry in "${PHOTOS[@]}"; do
  read -r id w h <<< "$entry"
  file="$DEST/sample_$id.jpg"
  echo "  picsum id=$id (${w}x${h})"
  curl -fsSL --max-time 60 "https://picsum.photos/id/$id/$w/$h" -o "$file" && count=$((count+1)) || echo "    ! id=$id は取得失敗(スキップ)"
done

echo "→ $count 枚ダウンロード完了。シミュレータに追加します..."
if xcrun simctl addmedia booted "$DEST"/*.jpg 2>/dev/null; then
  echo "✔ 完了: シミュレータの写真アプリに追加されました"
else
  echo "! シミュレータが起動していません。起動後に以下を実行してください:"
  echo "  xcrun simctl addmedia booted \"$DEST\"/*.jpg"
fi
