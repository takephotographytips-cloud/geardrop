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

# ID: Picsum の安定ID。スクショ映えを重視し、アプリの 4:5 キャンバスと相性の良い
# 縦位置(3000x3750)を中心に選定。suffix で加工指定:
#   (なし)=カラー / g=グレースケール(モノ/フィルム作例用) / q=正方形
# 番号順で連番保存するので、写真アプリ上でも狙った並びで表示される。
PHOTOS=(
  # --- セットA: 山・湖・冷色(縦積み作例向き) ---
  "1018 3000 3750 -"   # 山と湖
  "1015 3000 3750 -"   # 渓谷と川
  "1039 3000 3750 -"   # 滝
  # --- セットB: 海・夕景・暖色 ---
  "1019 3000 3750 -"   # 湖と夕景
  "110  3000 3750 -"   # 海岸
  "1036 3000 3750 -"   # 雪山
  # --- モノ/フィルム作例(グレースケール) ---
  "1043 3000 3750 g"   # 街灯(モノ)
  "1050 3000 3750 g"   # 建築(モノ)
  # --- 品質訴求(なだらかな空グラデ = バンディング検証にも) ---
  "1016 3000 3750 -"   # 山と空
  "1022 3000 3750 -"   # 夜空
  # --- 予備・横位置/正方形 ---
  "1044 4000 2667 -"   # 月夜(横)
  "1080 3000 3000 q"   # 静物(正方)
)

echo "→ ダウンロード先: $DEST"
count=0
index=1
for entry in "${PHOTOS[@]}"; do
  read -r id w h mode <<< "$entry"
  # 連番プレフィックスで並び順を安定させる
  seq=$(printf "%02d" "$index")
  file="$DEST/stack_${seq}_${id}.jpg"
  url="https://picsum.photos/id/$id/$w/$h"
  [ "$mode" = "g" ] && url="$url?grayscale"
  echo "  [$seq] picsum id=$id (${w}x${h}${mode:+ $mode})"
  curl -fsSL --max-time 60 "$url" -o "$file" && count=$((count+1)) || echo "    ! id=$id は取得失敗(スキップ)"
  index=$((index+1))
done

echo "→ $count 枚ダウンロード完了。シミュレータに追加します..."
if xcrun simctl addmedia booted "$DEST"/*.jpg 2>/dev/null; then
  echo "✔ 完了: シミュレータの写真アプリに追加されました"
else
  echo "! シミュレータが起動していません。起動後に以下を実行してください:"
  echo "  xcrun simctl addmedia booted \"$DEST\"/*.jpg"
fi
