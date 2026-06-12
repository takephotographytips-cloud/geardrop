#!/usr/bin/env python3
"""
宣材写真 AI生成 検証パイプライン
使い方: python generate.py
"""

import json
import os
import sys
import time
import webbrowser
from datetime import datetime
from pathlib import Path

import replicate
import requests
from PIL import Image

from presets import PRESETS

# ─── 設定 ───────────────────────────────────────────────
MODEL_ID = "black-forest-labs/flux-kontext-pro"
INPUT_DIR = Path(__file__).parent / "input" / "selfies"
OUTPUT_BASE = Path(__file__).parent / "output"
MAX_RETRIES = 2
REPORT_TEMPLATE = Path(__file__).parent / "report_template.html"

# 1 USD = 145円（概算）
USD_TO_JPY = 145
COST_PER_IMAGE_USD = 0.04


def check_env():
    token = os.environ.get("REPLICATE_API_TOKEN")
    if not token:
        print("ERROR: 環境変数 REPLICATE_API_TOKEN が設定されていません。")
        print("  export REPLICATE_API_TOKEN=あなたのキー  を実行してください。")
        sys.exit(1)


def try_face_detection(img_path: Path) -> int:
    """OpenCV で顔を検出して検出数を返す。OpenCV 未インストールでも動く。"""
    try:
        import cv2
        import numpy as np

        img = cv2.imread(str(img_path))
        if img is None:
            return -1
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        face_cascade = cv2.CascadeClassifier(cascade_path)
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(80, 80))
        return len(faces)
    except ImportError:
        return -1  # opencv なしの場合はスキップ


def check_input_images(selfies: list[Path]) -> list[Path]:
    """画像の解像度・顔の有無を簡易チェックし、警告を出す。"""
    print(f"\n── 入力チェック ({len(selfies)} 枚) ──────────────────────────")
    valid = []
    for p in selfies:
        try:
            with Image.open(p) as img:
                w, h = img.size
                short_side = min(w, h)
                warnings = []
                if short_side < 512:
                    warnings.append(f"解像度が低い ({w}x{h}px、短辺512px推奨)")
                face_count = try_face_detection(p)
                if face_count == 0:
                    warnings.append("顔が検出できません（マスク・強い逆光・横向きすぎる可能性）")
                elif face_count > 1:
                    warnings.append(f"複数の顔を検出 ({face_count}人)。1人だけ写った写真を推奨")

                status = "⚠ 警告あり" if warnings else "✓"
                print(f"  {status}  {p.name}  ({w}x{h}px)", end="")
                if face_count >= 1:
                    print(f"  顔:{face_count}個", end="")
                if face_count == -1:
                    print("  顔検出:スキップ(opencv未インストール)", end="")
                print()
                for w_msg in warnings:
                    print(f"       → {w_msg}")
                valid.append(p)
        except Exception as e:
            print(f"  × {p.name}  読み込みエラー: {e} → スキップ")
    print()
    return valid


def generate_with_retry(selfie_path: Path, preset: dict, seed: int, run_dir: Path) -> dict | None:
    """1枚分を生成してダウンロード。失敗は最大 MAX_RETRIES 回リトライ。"""
    stem = selfie_path.stem
    out_filename = f"{stem}_s{seed}.png"
    out_path = run_dir / out_filename

    for attempt in range(MAX_RETRIES + 1):
        try:
            start = time.time()
            with open(selfie_path, "rb") as f:
                output = replicate.run(
                    MODEL_ID,
                    input={
                        "prompt": preset["prompt"],
                        "input_image": f,
                        "seed": seed,
                        "aspect_ratio": preset["aspect_ratio"],
                        "output_format": preset["output_format"],
                        "safety_tolerance": preset["safety_tolerance"],
                    },
                )
            elapsed = round(time.time() - start, 1)

            # output は URL またはファイルライクオブジェクトのリスト
            image_url = output[0] if isinstance(output, list) else output
            if hasattr(image_url, "url"):
                image_url = image_url.url
            image_url = str(image_url)

            # ダウンロード
            resp = requests.get(image_url, timeout=60)
            resp.raise_for_status()
            out_path.write_bytes(resp.content)

            cost_usd = COST_PER_IMAGE_USD
            cost_jpy = round(cost_usd * USD_TO_JPY, 1)
            print(f"    ✓ seed={seed}  {elapsed}s  ${cost_usd:.2f}(約{cost_jpy}円)  → {out_filename}")

            return {
                "source_image": selfie_path.name,
                "output_file": out_filename,
                "model": MODEL_ID,
                "preset": preset["name"],
                "seed": seed,
                "elapsed_sec": elapsed,
                "cost_usd": cost_usd,
                "cost_jpy": cost_jpy,
                "status": "ok",
            }

        except Exception as e:
            if attempt < MAX_RETRIES:
                wait = 2 ** (attempt + 1)
                print(f"    リトライ {attempt + 1}/{MAX_RETRIES}  ({e})  {wait}秒待機...")
                time.sleep(wait)
            else:
                print(f"    × 失敗: {e}")
                return {
                    "source_image": selfie_path.name,
                    "output_file": None,
                    "model": MODEL_ID,
                    "preset": preset["name"],
                    "seed": seed,
                    "elapsed_sec": None,
                    "cost_usd": 0,
                    "cost_jpy": 0,
                    "status": "error",
                    "error": str(e),
                }


def generate_report(run_dir: Path, logs: list[dict], selfies: list[Path]):
    """report.html を生成する。"""

    total_cost_usd = sum(r["cost_usd"] for r in logs)
    total_cost_jpy = round(total_cost_usd * USD_TO_JPY, 1)
    ok_count = sum(1 for r in logs if r["status"] == "ok")
    fail_count = len(logs) - ok_count
    run_dt = run_dir.name

    # 自撮りごとに生成結果をグループ化
    groups: dict[str, dict] = {}
    for selfie in selfies:
        groups[selfie.name] = {"selfie": selfie, "results": []}
    for r in logs:
        if r["source_image"] in groups:
            groups[r["source_image"]]["results"].append(r)

    # 自撮り画像を report.html と同じディレクトリにコピーして相対パスで参照
    import shutil

    for selfie in selfies:
        dest = run_dir / ("src_" + selfie.name)
        if not dest.exists():
            shutil.copy2(selfie, dest)

    # セクションHTML生成
    sections_html = ""
    for name, group in groups.items():
        selfie_file = "src_" + name
        cards_html = ""
        for i, r in enumerate(group["results"], 1):
            if r["status"] == "ok":
                img_tag = f'<img src="{r["output_file"]}" class="gen-img" loading="lazy">'
            else:
                img_tag = '<div class="gen-img error-placeholder">生成失敗</div>'

            defect_fields = ""
            for label in ["目", "歯", "耳", "髪の生え際", "手指", "服のシワ", "背景の濁り"]:
                field_id = f"defect_{r['source_image']}_{r['seed']}_{label}"
                defect_fields += (
                    f'<label class="chk-label">'
                    f'<input type="checkbox" class="defect-chk" data-source="{r["source_image"]}" '
                    f'data-seed="{r["seed"]}" data-label="{label}"> {label}'
                    f'</label>'
                )

            star_html = ""
            for s in range(1, 6):
                star_html += (
                    f'<input type="radio" class="star-radio" name="star_{r["source_image"]}_{r["seed"]}" '
                    f'id="star_{r["source_image"]}_{r["seed"]}_{s}" value="{s}" '
                    f'data-source="{r["source_image"]}" data-seed="{r["seed"]}">'
                    f'<label for="star_{r["source_image"]}_{r["seed"]}_{s}" class="star-lbl">★</label>'
                )

            cost_info = f"seed={r['seed']} / {r['elapsed_sec']}s / ¥{r['cost_jpy']}" if r["status"] == "ok" else f"seed={r['seed']} / 失敗"
            cards_html += f"""
            <div class="gen-card" data-source="{r['source_image']}" data-seed="{r['seed']}">
              {img_tag}
              <div class="meta">{cost_info}</div>
              <div class="stars">{star_html}</div>
              <div class="defects">{defect_fields}</div>
              <textarea class="memo" placeholder="メモ..."
                data-source="{r['source_image']}" data-seed="{r['seed']}"></textarea>
            </div>"""

        sections_html += f"""
        <section class="selfie-section">
          <h2>{name}</h2>
          <div class="comparison-grid">
            <div class="source-col">
              <div class="col-label">元の自撮り</div>
              <img src="{selfie_file}" class="src-img">
            </div>
            <div class="gen-col">
              <div class="col-label">生成結果（4バリエーション）</div>
              <div class="gen-grid">{cards_html}</div>
            </div>
          </div>
        </section>"""

    html = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>宣材写真AI検証レポート {run_dt}</title>
<style>
  :root {{
    --bg: #f5f5f5; --card: #fff; --border: #ddd;
    --star-on: #f5a623; --star-off: #ccc;
    --accent: #2563eb;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: -apple-system, 'Helvetica Neue', sans-serif; background: var(--bg); color: #333; }}
  header {{ background: #1e293b; color: #fff; padding: 20px 32px; }}
  header h1 {{ font-size: 1.3rem; margin-bottom: 8px; }}
  .summary-grid {{ display: flex; gap: 24px; flex-wrap: wrap; margin-top: 10px; }}
  .summary-item {{ background: rgba(255,255,255,.1); border-radius: 6px; padding: 8px 16px; font-size: .9rem; }}
  .summary-item span {{ font-size: 1.4rem; font-weight: bold; display: block; }}
  main {{ max-width: 1400px; margin: 0 auto; padding: 24px 16px; }}
  .selfie-section {{ background: var(--card); border: 1px solid var(--border); border-radius: 10px;
    padding: 20px; margin-bottom: 32px; }}
  .selfie-section h2 {{ font-size: 1rem; color: #555; margin-bottom: 16px; border-bottom: 1px solid var(--border); padding-bottom: 8px; }}
  .comparison-grid {{ display: flex; gap: 20px; align-items: flex-start; }}
  .source-col {{ flex: 0 0 220px; }}
  .gen-col {{ flex: 1; }}
  .col-label {{ font-size: .75rem; color: #888; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 8px; }}
  .src-img {{ width: 100%; border-radius: 6px; border: 1px solid var(--border); }}
  .gen-grid {{ display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px; }}
  .gen-card {{ background: var(--bg); border-radius: 8px; padding: 10px; border: 1px solid var(--border); }}
  .gen-img {{ width: 100%; border-radius: 4px; display: block; cursor: zoom-in; }}
  .error-placeholder {{ width: 100%; aspect-ratio: 3/4; background: #fee2e2; border-radius: 4px;
    display: flex; align-items: center; justify-content: center; color: #dc2626; font-size: .85rem; }}
  .meta {{ font-size: .72rem; color: #888; margin: 6px 0 8px; }}
  /* 星評価 */
  .stars {{ display: flex; flex-direction: row-reverse; justify-content: flex-end; margin-bottom: 8px; }}
  .star-radio {{ display: none; }}
  .star-lbl {{ font-size: 1.4rem; color: var(--star-off); cursor: pointer; transition: color .1s; }}
  .star-radio:checked ~ .star-lbl,
  .star-lbl:hover, .star-lbl:hover ~ .star-lbl {{ color: var(--star-on); }}
  /* チェックボックス */
  .defects {{ display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 8px; }}
  .chk-label {{ font-size: .75rem; background: #fff; border: 1px solid var(--border); border-radius: 4px;
    padding: 2px 6px; cursor: pointer; white-space: nowrap; }}
  .chk-label:has(input:checked) {{ background: #fee2e2; border-color: #fca5a5; color: #b91c1c; }}
  .memo {{ width: 100%; border: 1px solid var(--border); border-radius: 4px; padding: 6px; font-size: .8rem;
    resize: vertical; min-height: 48px; font-family: inherit; }}
  /* 拡大モーダル */
  #modal {{ display:none; position:fixed; inset:0; background:rgba(0,0,0,.8); z-index:999;
    align-items:center; justify-content:center; cursor:zoom-out; }}
  #modal.open {{ display:flex; }}
  #modal img {{ max-width:90vw; max-height:90vh; border-radius:8px; }}
  /* エクスポートボタン */
  .export-btn {{ display:block; margin: 16px auto 0; padding: 10px 28px; background: var(--accent);
    color: #fff; border: none; border-radius: 6px; font-size: .95rem; cursor: pointer; }}
  .export-btn:hover {{ background: #1d4ed8; }}
  @media (max-width: 700px) {{
    .comparison-grid {{ flex-direction: column; }}
    .source-col {{ flex: none; width: 100%; }}
    .gen-grid {{ grid-template-columns: 1fr 1fr; }}
  }}
</style>
</head>
<body>
<header>
  <h1>宣材写真 AI生成 検証レポート</h1>
  <div class="summary-grid">
    <div class="summary-item">実行日時<span>{run_dt}</span></div>
    <div class="summary-item">使用モデル<span style="font-size:.9rem">{MODEL_ID}</span></div>
    <div class="summary-item">生成成功<span>{ok_count} 枚</span></div>
    <div class="summary-item">失敗<span>{fail_count} 枚</span></div>
    <div class="summary-item">総コスト<span>¥{total_cost_jpy:.0f}（${total_cost_usd:.2f}）</span></div>
    <div class="summary-item">1枚あたり<span>¥{round(COST_PER_IMAGE_USD * USD_TO_JPY)}（${COST_PER_IMAGE_USD:.2f}）</span></div>
  </div>
</header>
<main>
{sections_html}
<button class="export-btn" onclick="exportJSON()">評価データをJSONで保存</button>
</main>

<div id="modal"><img id="modal-img" src="" alt=""></div>

<script>
// 画像クリックで拡大
document.querySelectorAll('.gen-img').forEach(img => {{
  img.addEventListener('click', () => {{
    document.getElementById('modal-img').src = img.src;
    document.getElementById('modal').classList.add('open');
  }});
}});
document.getElementById('modal').addEventListener('click', () => {{
  document.getElementById('modal').classList.remove('open');
}});

function collectEvaluations() {{
  const evals = {{}};
  // 星評価
  document.querySelectorAll('.star-radio:checked').forEach(r => {{
    const key = r.dataset.source + '__' + r.dataset.seed;
    if (!evals[key]) evals[key] = {{ source: r.dataset.source, seed: r.dataset.seed }};
    evals[key].star = parseInt(r.value);
  }});
  // チェックボックス
  document.querySelectorAll('.defect-chk:checked').forEach(c => {{
    const key = c.dataset.source + '__' + c.dataset.seed;
    if (!evals[key]) evals[key] = {{ source: c.dataset.source, seed: c.dataset.seed }};
    if (!evals[key].defects) evals[key].defects = [];
    evals[key].defects.push(c.dataset.label);
  }});
  // メモ
  document.querySelectorAll('.memo').forEach(t => {{
    if (t.value.trim()) {{
      const key = t.dataset.source + '__' + t.dataset.seed;
      if (!evals[key]) evals[key] = {{ source: t.dataset.source, seed: t.dataset.seed }};
      evals[key].memo = t.value.trim();
    }}
  }});
  return Object.values(evals);
}}

function exportJSON() {{
  const data = {{
    run_datetime: "{run_dt}",
    model: "{MODEL_ID}",
    total_cost_jpy: {total_cost_jpy},
    evaluations: collectEvaluations()
  }};
  const blob = new Blob([JSON.stringify(data, null, 2)], {{ type: 'application/json' }});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'eval_{run_dt}.json';
  a.click();
}}
</script>
</body>
</html>"""

    report_path = run_dir / "report.html"
    report_path.write_text(html, encoding="utf-8")
    return report_path


def main():
    check_env()

    # 出力ディレクトリを日時で作成
    run_dt = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = OUTPUT_BASE / run_dt
    run_dir.mkdir(parents=True, exist_ok=True)

    # 自撮り画像を収集
    exts = {".jpg", ".jpeg", ".png", ".webp"}
    selfies = sorted(p for p in INPUT_DIR.iterdir() if p.suffix.lower() in exts)
    if not selfies:
        print(f"ERROR: {INPUT_DIR} に画像が見つかりません。")
        print("  JPEG/PNG/WEBP の自撮りを入れてから再実行してください。")
        sys.exit(1)

    print(f"\n宣材写真AI生成 検証パイプライン")
    print(f"モデル: {MODEL_ID}")
    print(f"出力先: {run_dir}")

    # 入力チェック
    valid_selfies = check_input_images(selfies)

    # 生成ループ
    all_logs = []
    failed_summary = []

    for selfie in valid_selfies:
        print(f"\n── 生成: {selfie.name} ──────────────────────────")
        for preset in PRESETS:
            for seed in preset["seeds"]:
                result = generate_with_retry(selfie, preset, seed, run_dir)
                if result:
                    all_logs.append(result)
                    if result["status"] == "error":
                        failed_summary.append(f"  {selfie.name} seed={seed}: {result.get('error','')}")

    # JSONログ保存
    log_path = run_dir / "run_log.json"
    log_path.write_text(json.dumps(all_logs, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n実行ログ保存: {log_path}")

    # 失敗サマリー
    if failed_summary:
        print(f"\n── 失敗一覧 ({len(failed_summary)} 件) ──────────────────────────")
        for f in failed_summary:
            print(f)

    # 集計
    ok_count = sum(1 for r in all_logs if r["status"] == "ok")
    total_cost_usd = ok_count * COST_PER_IMAGE_USD
    total_cost_jpy = round(total_cost_usd * USD_TO_JPY)
    print(f"\n── 完了 ─────────────────────────────────────────")
    print(f"  生成成功: {ok_count} 枚  失敗: {len(failed_summary)} 件")
    print(f"  総コスト: ${total_cost_usd:.2f} ≈ ¥{total_cost_jpy}")

    # レポート生成
    report_path = generate_report(run_dir, all_logs, valid_selfies)
    print(f"  レポート: {report_path}")
    print("\nブラウザでレポートを開きます...")
    webbrowser.open(report_path.as_uri())


if __name__ == "__main__":
    main()
