#!/usr/bin/env python3
"""App Store スクリーンショット合成スクリプト(Mac で実行)。

シミュレータ(iPhone 16 Pro Max)で撮ったスクショにキャッチコピーを載せ、
提出サイズ 1320x2868 の完成品を出力する。

使い方:
  1. pip3 install pillow   (初回のみ)
  2. シミュレータで6画面を ⌘S で撮影し、以下の名前で
     ~/Downloads/stack-shots/ に置く:
       shot1.png .. shot6.png  (内容は screenshot_copy.md の表の順)
  3. python3 CollageApp/AppStore/make_screenshots.py
  4. ~/Downloads/stack-shots/out/ に final_1.png .. final_6.png が出力される
     → App Store Connect にそのままアップロード

コピーを変えたいときは下の CAPTIONS を編集するだけ。
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    sys.exit("Pillow が必要です: pip3 install pillow")

# ===== 設定 =====
CANVAS = (1320, 2868)          # 6.9インチ 提出サイズ
BG = (0xF5, 0xF2, 0xED)        # ブランドのオフホワイト
INK = (0x2A, 0x28, 0x24)
SUB = (0x6E, 0x6A, 0x62)
SHOT_DIR = Path.home() / "Downloads" / "stack-shots"
OUT_DIR = SHOT_DIR / "out"

# (メインコピー, サブコピー) 撮影済みの5枚に対応
# shot1: 縦3枚+余白 / shot2: イエローネガ / shot3: 調整モード(グリッド)
# shot4: スポイト使用中(横2枚) / shot5: 単写真+黒背景(画質)
CAPTIONS = [
    ("3タップで、作品になる", "選ぶ、ならべる、保存する"),
    ("フィルムの質感を、そのまま", "ネガ・シネマ・プリント、4つのフレーム"),
    ("傾きも、指先ひとつで", "±15°の水平調整と90°回転"),
    ("色は、写真から拾う", "スポイトで写真の色を余白に"),
    ("画質に、一切の妥協なし", "フル解像度・16bit処理・EXIF保持"),
]

# macOS の日本語フォント候補(上から順に探す)
FONT_CANDIDATES = [
    "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/Supplemental/ヒラギノ角ゴ Pro W6.otf",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    sys.exit("日本語フォントが見つかりません(macOS で実行してください)")


def rounded_screenshot(shot, width, radius):
    """スクショを指定幅に縮小し、角丸マスクを適用して返す"""
    ratio = width / shot.width
    shot = shot.resize((width, int(shot.height * ratio)), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (shot.width - 1, shot.height - 1)], radius=radius, fill=255
    )
    shot.putalpha(mask)
    return shot


def fitted_font(draw, text, base_size, max_width):
    """max_width に収まるまでフォントサイズを自動で縮める"""
    size = base_size
    while size > 24:
        font = load_font(size)
        if draw.textlength(text, font=font) <= max_width:
            return font
        size -= 4
    return load_font(size)


def compose(index, shot_path, title, subtitle):
    canvas = Image.new("RGB", CANVAS, BG)
    draw = ImageDraw.Draw(canvas)

    # キャッチコピー(中央揃え・左右60px余白を必ず確保、長文は自動縮小)
    side_margin = 60
    max_text_width = CANVAS[0] - side_margin * 2
    title_font = fitted_font(draw, title, 96, max_text_width)
    sub_font = fitted_font(draw, subtitle, 52, max_text_width)

    # 上下バランス: 見出しブロックを y=150〜440 に収めて中央配置
    title_h = title_font.size
    sub_h = sub_font.size
    block_gap = 44
    block_top = 150 + (290 - (title_h + block_gap + sub_h)) / 2

    tw = draw.textlength(title, font=title_font)
    draw.text(((CANVAS[0] - tw) / 2, block_top), title, font=title_font, fill=INK)
    sw = draw.textlength(subtitle, font=sub_font)
    draw.text(((CANVAS[0] - sw) / 2, block_top + title_h + block_gap), subtitle, font=sub_font, fill=SUB)

    # スクリーンショット(角丸+影)
    shot = Image.open(shot_path).convert("RGB")
    shot = rounded_screenshot(shot, width=1110, radius=56)
    x = (CANVAS[0] - shot.width) // 2
    y = 470

    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [(x, y + 14), (x + shot.width, y + 14 + shot.height)],
        radius=56, fill=(42, 40, 36, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(shot, (x, y), shot)

    out = OUT_DIR / f"final_{index}.png"
    canvas.save(out)
    print(f"  ✔ {out.name}  ({title})")


def main():
    if not SHOT_DIR.exists():
        sys.exit(f"フォルダがありません: {SHOT_DIR}\n"
                 "シミュレータのスクショを shot1.png〜shot6.png の名前で置いてください")
    OUT_DIR.mkdir(exist_ok=True)
    made = 0
    for i, (title, subtitle) in enumerate(CAPTIONS, start=1):
        shot = SHOT_DIR / f"shot{i}.png"
        if not shot.exists():
            print(f"  - shot{i}.png が無いためスキップ")
            continue
        compose(i, shot, title, subtitle)
        made += 1
    print(f"完了: {made}枚 → {OUT_DIR}")


if __name__ == "__main__":
    main()
