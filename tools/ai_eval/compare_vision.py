#!/usr/bin/env python3
"""Vision meal-analysis model bake-off for NutriLens.

Runs the SAME meal-analysis prompt used in production
(`AnthropicAiService._mealAnalysisPrompt`) against several candidate
OpenRouter vision models plus Claude, on a folder of real food photos, and
prints food_name / portion / kcal / confidence side by side so you can pick
the cheapest model whose recognition quality holds.

Usage:
    python tools/ai_eval/compare_vision.py <image_dir> [tr|en]

Requirements:
    - OPENROUTER_API_KEY in .env   (free at openrouter.ai)
    - ANTHROPIC_API_KEY in .env    (the Claude baseline; optional)
    Stdlib only, no pip installs.
"""

import base64
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request

# ── Candidate models ──────────────────────────────────────────────────
# OpenRouter ids (OpenAI-compatible chat/completions). Edit freely.
OPENROUTER_MODELS = [
    "meta-llama/llama-4-scout",
    "qwen/qwen3-vl-8b-instruct",
    "amazon/nova-lite-v1",
    "openai/gpt-4.1-nano",
]
# Claude baseline (direct Anthropic Messages API). Set to None to skip.
ANTHROPIC_MODEL = "claude-sonnet-4-0"

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
TIMEOUT = 90


def language_name(code: str) -> str:
    return {"en": "English", "tr": "Turkish"}.get(code, "Turkish")


def meal_prompt(code: str) -> str:
    """Kept in sync with AnthropicAiService._mealAnalysisPrompt."""
    ln = language_name(code)
    return f"""Bu görseldeki öğünü analiz et. Amacın TEK KİŞİNİN yediği porsiyonu
gramaj + besin değeri olarak döndürmek.

Yanıt dili: {ln}. `food_name`, `ingredients_text` ve
`description` alanlarını {ln} dilinde yaz (yemek adını da bu dile
çevir; örn. İngilizce için "Etli Pilav" -> "Rice with Meat").

Önce şu kararı ver:
1. BİREYSEL porsiyon mu? (Bir kişinin önünde duran, tek başına yeneceği
   bir kase/tabak.)
2. PAYLAŞIMLI tabak/tencere mi? (Ortaya konmuş büyük servis tabağı.)

PAYLAŞIMLI ise: Sadece BİR kişinin alacağı tipik porsiyonu hesapla
(yaklaşık 150-250 g). Tabaktaki toplam yemeği DEĞİL.
BİREYSEL ise: Görseldeki gerçek miktarı tahmin et.

Sert kurallar:
- 50 g'dan az veya 350 g'dan fazla TEK KİŞİLİK porsiyon DÖNDÜRME.
- Default olarak 100 g sabiti KULLANMA. Fotoğrafa ve yemek tipine bak.
- `portion_grams`: bir kişinin yediği toplam gramaj.
- `nutrition`: o porsiyonun TOPLAM besin değerleri (100 g için değil).
- İçindekileri ({ln}) düz metin olarak yaz.
- Belirsizse yine en iyi tahmini yap, `confidence` düşük olur.
- Bulamadığın besin değerlerini 0 döndür.
- Sadece JSON döndür, açıklama veya markdown yazma.

Şema:
{{
  "food_name": string,
  "portion_grams": number,
  "ingredients_text": string,
  "nutrition": {{"energy_kcal": number, "fat": number, "saturated_fat": number,
    "trans_fat": number, "carbohydrates": number, "sugars": number,
    "salt": number, "fiber": number, "protein": number}},
  "confidence": number,
  "description": string
}}"""


def load_env(path: str = ".env") -> dict:
    env = {}
    if not os.path.exists(path):
        return env
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def extract_json(text: str):
    t = text.strip()
    if "```" in t:
        # strip ```json ... ``` fences
        import re

        m = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", t)
        if m:
            t = m.group(1).strip()
    start = t.find("{")
    end = t.rfind("}")
    if start != -1 and end != -1:
        t = t[start : end + 1]
    return json.loads(t)


def post(url: str, headers: dict, payload: dict):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def call_openrouter(model, key, b64, media, prompt):
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://nutrilenshq.com",
        "X-Title": "NutriLens model eval",
    }
    payload = {
        "model": model,
        "max_tokens": 1000,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{media};base64,{b64}"},
                    },
                ],
            }
        ],
    }
    resp = post(OPENROUTER_URL, headers, payload)
    return resp["choices"][0]["message"]["content"]


def call_anthropic(model, key, b64, media, prompt):
    headers = {
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "max_tokens": 1000,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "base64", "media_type": media, "data": b64},
                    },
                    {"type": "text", "text": prompt},
                ],
            }
        ],
    }
    resp = post(ANTHROPIC_URL, headers, payload)
    return resp["content"][0]["text"]


def summarize(raw_text):
    try:
        j = extract_json(raw_text)
        n = j.get("nutrition", {}) or {}
        return {
            "food": str(j.get("food_name", "?"))[:34],
            "g": j.get("portion_grams", "?"),
            "kcal": n.get("energy_kcal", "?"),
            "conf": j.get("confidence", "?"),
        }
    except Exception as e:  # noqa: BLE001
        return {"food": f"[parse-fail: {str(e)[:24]}]", "g": "", "kcal": "", "conf": ""}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    image_dir = sys.argv[1]
    lang = sys.argv[2] if len(sys.argv) > 2 else "tr"
    prompt = meal_prompt(lang)

    env = load_env()
    or_key = env.get("OPENROUTER_API_KEY", "")
    an_key = env.get("ANTHROPIC_API_KEY", "")
    if not or_key:
        print("!! OPENROUTER_API_KEY missing in .env")
    if not an_key:
        print("!! ANTHROPIC_API_KEY missing in .env (Claude baseline skipped)")

    exts = (".jpg", ".jpeg", ".png", ".webp")
    images = sorted(
        f for f in os.listdir(image_dir) if f.lower().endswith(exts)
    )
    if not images:
        print(f"No images ({', '.join(exts)}) found in {image_dir}")
        sys.exit(1)

    runners = []
    if an_key and ANTHROPIC_MODEL:
        runners.append(("CLAUDE " + ANTHROPIC_MODEL, lambda b, m: call_anthropic(ANTHROPIC_MODEL, an_key, b, m, prompt)))
    for mid in OPENROUTER_MODELS:
        if or_key:
            runners.append((mid, (lambda model: lambda b, m: call_openrouter(model, or_key, b, m, prompt))(mid)))

    for img in images:
        path = os.path.join(image_dir, img)
        with open(path, "rb") as fh:
            b64 = base64.standard_b64encode(fh.read()).decode("ascii")
        media = mimetypes.guess_type(path)[0] or "image/jpeg"
        print("\n" + "=" * 78)
        print(f"IMAGE: {img}")
        print("-" * 78)
        print(f"{'model':<34}{'food':<36}{'g':>5}{'kcal':>6}{'conf':>6}  {'s':>5}")
        for name, fn in runners:
            t0 = time.time()
            try:
                raw = fn(b64, media)
                s = summarize(raw)
                dt = time.time() - t0
                print(
                    f"{name[:33]:<34}{str(s['food']):<36}{str(s['g']):>5}"
                    f"{str(s['kcal']):>6}{str(s['conf']):>6}  {dt:5.1f}"
                )
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", "ignore")[:80]
                print(f"{name[:33]:<34}HTTP {e.code}: {body}")
            except Exception as e:  # noqa: BLE001
                print(f"{name[:33]:<34}ERROR: {str(e)[:60]}")


if __name__ == "__main__":
    main()
