"""生成プロンプト定義"""

PRESET_01 = {
    "name": "白ホリ × 白T × フラット光（バストアップ）",
    "prompt": (
        "A professional Japanese talent promotional headshot (senzai-shashin), "
        "bust-up framing from the chest up, centered composition with natural headroom, "
        "plain seamless white cyclorama studio background — pure white, no gradient, "
        "no vignette, no visible floor line. "
        "Flat, even frontal lighting from a large softbox key with strong fill, "
        "shadowless white background, soft natural catchlights in both eyes. "
        "Subject wears a plain white crew-neck T-shirt with no logos or prints. "
        "Upright natural posture, shoulders relaxed and squared to camera, "
        "gentle confident closed-mouth smile, eyes looking directly into the lens. "
        "Shot on an 85mm portrait lens at f/5.6, tack-sharp focus on the eyes, "
        "true-to-life skin texture with visible pores, accurate skin tone under "
        "5500K daylight-balanced strobes. "
        "CRITICAL: preserve the subject's facial identity exactly as in the reference "
        "photo — do not alter face shape, eye size, nose, jawline, skin tone, "
        "hairstyle, or apparent age. No skin smoothing, no beautification, "
        "no added makeup. Vertical 3:4 aspect ratio, high-resolution commercial "
        "photography quality."
    ),
    "aspect_ratio": "3:4",
    "output_format": "png",
    "safety_tolerance": 2,
    "seeds": [42, 1337, 7777, 31415],
}

PRESETS = [PRESET_01]
