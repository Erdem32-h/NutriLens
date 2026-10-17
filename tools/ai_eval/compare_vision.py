#!/usr/bin/env python3
"""Vision meal-analysis model bake-off for NutriLens.

Sends the production meal-analysis request to each candidate OpenRouter model:
the prompt is read straight out of supabase/functions/gemini-proxy/index.ts
(mealAnalysisPrompt), and the message shape + params mirror
handleOpenRouterAction, so the eval can never drift from what users get.
Reports latency, OpenRouter-billed cost, JSON validity and the parsed answer
for every call.

Usage:
    python tools/ai_eval/compare_vision.py <image_dir> [--lang tr] [--runs 2]
        [--models id1,id2] [--workers 6] [--out results.jsonl]

Scoring: if <image_dir>/ground_truth.json exists
({stem: {"label": str, "accept": [keywords], "food_source": [allowed]}}),
each answer is scored for dish recognition (any keyword in food_name or
description) and food_source match.

Requirements:
    - OPENROUTER_API_KEY in tools/ai_eval/.env
    Stdlib only, no pip installs.

    Deliberately NOT the project-root .env: pubspec.yaml bundles that file as
    a Flutter asset, so anything added there ends up readable inside the
    built APK/IPA. The eval key must never live in a bundled asset.
"""

import argparse
import base64
import json
import random
import re
import statistics
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PROXY_SRC = REPO / "supabase" / "functions" / "gemini-proxy" / "index.ts"
ENV_PATH = Path(__file__).resolve().parent / ".env"

# ── Candidate models ──────────────────────────────────────────────────
# First entry is the production baseline. Edit freely.
DEFAULT_MODELS = [
    "google/gemini-2.5-flash",
    "google/gemini-2.5-flash-lite",
    "google/gemini-3.5-flash-lite",
    "anthropic/claude-haiku-5.5",
    "openai/gpt-5-nano",
    "qwen/qwen3.7-flash",
    "google/gemma-4-26b-a4b-it",
]
# Per-model request tweaks on top of the production params; a None value
# drops the key. Measured 2026-10-17 with production params unchanged: both
# reasoning models below spent the whole 1000-token budget thinking and
# returned EMPTY content (Haiku 5.5: 1000/1000 reasoning tokens, 10 s;
# gpt-5-nano: 960/1000, 20 s). In production that silently falls through to
# the direct-Gemini fallback — switching either in via OPENROUTER_MEAL_MODEL
# alone would look like it works while serving Gemini.
MODEL_OVERRIDES: dict = {
    "anthropic/claude-haiku-5.5": {"reasoning": {"enabled": False}},
    "openai/gpt-5-nano": {"reasoning": {"effort": "minimal"}},
}

# Mirrors handleOpenRouterAction + callOpenRouter for action=meal_analysis.
PRODUCTION_PARAMS = {
    "max_tokens": 1000,
    "temperature": 0.2,
    "response_format": {"type": "json_object"},
    "usage": {"include": True},
}
LANGS = {"tr": "Turkish", "en": "English", "de": "German", "fr": "French",
         "es": "Spanish", "ar": "Arabic"}
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
TIMEOUT = 90
FOOD_SOURCES = {"homemade", "packaged", "restaurant"}


def meal_prompt(lang: str) -> str:
    """The production prompt, extracted from the edge function source."""
    src = PROXY_SRC.read_text(encoding="utf-8")
    m = re.search(r"function mealAnalysisPrompt\([^)]*\)[^{]*\{.*?return `(.*?)`;",
                  src, re.S)
    if not m:
        raise SystemExit(f"mealAnalysisPrompt not found in {PROXY_SRC}")
    return m.group(1).replace("${ln}", LANGS.get(lang, "Turkish"))


def load_key() -> str:
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        if line.startswith("OPENROUTER_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise SystemExit(f"OPENROUTER_API_KEY missing in {ENV_PATH}")


def build_payload(model: str, prompt: str, b64: str) -> dict:
    payload = {"model": model, **PRODUCTION_PARAMS, "messages": [{
        "role": "user",
        "content": [
            {"type": "text", "text": prompt},
            {"type": "image_url",
             "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
        ],
    }]}
    for k, v in MODEL_OVERRIDES.get(model, {}).items():
        if v is None:
            payload.pop(k, None)
        else:
            payload[k] = v
    return payload


def extract_json(text: str) -> dict:
    t = text.strip()
    fence = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", t)
    if fence:
        t = fence.group(1)
    start, end = t.find("{"), t.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("no JSON object")
    return json.loads(t[start:end + 1])


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def judge(answer: dict, truth: dict | None) -> dict:
    """App-valid mirrors the tolerant Dart parser; strict checks the schema."""
    n = answer.get("nutrition") or {}
    kcal, conf = num(n.get("energy_kcal")), num(answer.get("confidence"))
    grams = num(answer.get("portion_grams"))
    src = str(answer.get("food_source", "")).strip().lower()
    out = {
        "app_valid": bool(answer.get("food_name")) and bool(kcal and kcal > 0),
        "strict": (conf is not None and 0 <= conf <= 1 and src in FOOD_SOURCES
                   and grams is not None and 50 <= grams <= 350),
    }
    if truth:
        hay = f"{answer.get('food_name', '')} {answer.get('description', '')}".casefold()
        out["dish_ok"] = any(k.casefold() in hay for k in truth["accept"])
        out["source_ok"] = src in truth["food_source"]
    return out


def call(task: dict, key: str, prompt: str) -> dict:
    model, img = task["model"], task["image"]
    b64 = base64.standard_b64encode(img.read_bytes()).decode("ascii")
    body = json.dumps(build_payload(model, prompt, b64)).encode("utf-8")
    req = urllib.request.Request(OPENROUTER_URL, data=body, method="POST", headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json",
        "HTTP-Referer": "https://nutrilenshq.com", "X-Title": "NutriLens model eval",
    })
    rec = {"model": model, "image": img.stem, "run": task["run"]}
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            resp = json.loads(r.read().decode("utf-8"))
        rec["seconds"] = round(time.time() - t0, 2)
    except urllib.error.HTTPError as e:
        rec.update(seconds=round(time.time() - t0, 2), error=f"HTTP {e.code}: "
                   + e.read().decode("utf-8", "ignore")[:200])
        return rec
    except Exception as e:  # noqa: BLE001 - every failure is a data point
        rec.update(seconds=round(time.time() - t0, 2), error=str(e)[:200])
        return rec
    usage = resp.get("usage") or {}
    rec.update(
        provider=resp.get("provider"),
        cost=usage.get("cost"),
        prompt_tokens=usage.get("prompt_tokens"),
        completion_tokens=usage.get("completion_tokens"),
        reasoning_tokens=(usage.get("completion_tokens_details") or {}).get("reasoning_tokens"),
    )
    text = ((resp.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
    try:
        answer = extract_json(text)
    except Exception as e:  # noqa: BLE001
        rec.update(error=f"parse: {e}", raw=text[:200])
        return rec
    n = answer.get("nutrition") or {}
    rec.update(answer={
        "food_name": answer.get("food_name"), "grams": answer.get("portion_grams"),
        "kcal": n.get("energy_kcal"), "protein": n.get("protein"),
        "carbs": n.get("carbohydrates"), "fat": n.get("fat"),
        "confidence": answer.get("confidence"), "food_source": answer.get("food_source"),
    }, **judge(answer, task.get("truth")))
    return rec


def pct(values: list, q: float):
    if not values:
        return None
    s = sorted(values)
    return s[min(len(s) - 1, int(round(q * (len(s) - 1))))]


def summarize(records: list, models: list) -> None:
    print(f"\n{'model':<32}{'ok':>7}{'dish':>7}{'src':>7}{'strict':>8}"
          f"{'p50 s':>7}{'p90 s':>7}{'max s':>7}{'$/call':>10}{'in tok':>8}{'out tok':>9}")
    for m in models:
        rs = [r for r in records if r["model"] == m]
        ok = [r for r in rs if "answer" in r]
        secs = [r["seconds"] for r in ok]
        costs = [r["cost"] for r in ok if r.get("cost") is not None]
        def rate(key):
            scored = [r for r in ok if key in r]
            return f"{sum(r[key] for r in scored)}/{len(scored)}" if scored else "-"
        mean = lambda xs: statistics.mean(xs) if xs else 0  # noqa: E731
        print(f"{m[:31]:<32}{len(ok):>3}/{len(rs):<3}{rate('dish_ok'):>7}"
              f"{rate('source_ok'):>7}{rate('strict'):>8}"
              f"{pct(secs, .5) or 0:>7.1f}{pct(secs, .9) or 0:>7.1f}{max(secs or [0]):>7.1f}"
              f"{mean(costs):>10.5f}{mean([r['prompt_tokens'] or 0 for r in ok]):>8.0f}"
              f"{mean([r['completion_tokens'] or 0 for r in ok]):>9.0f}")
    errors = [r for r in records if "error" in r]
    if errors:
        print("\nErrors:")
        for r in errors:
            print(f"  {r['model']:<32}{r['image']:<26}{r['error'][:110]}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("image_dir")
    ap.add_argument("--lang", default="tr")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--models", default=",".join(DEFAULT_MODELS))
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--out", default="results.jsonl")
    args = ap.parse_args()

    image_dir = Path(args.image_dir)
    images = sorted(p for p in image_dir.iterdir()
                    if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"))
    truth_path = image_dir / "ground_truth.json"
    truth = json.loads(truth_path.read_text(encoding="utf-8")) if truth_path.exists() else {}
    models = args.models.split(",")
    key, prompt = load_key(), meal_prompt(args.lang)

    tasks = [{"model": m, "image": img, "run": r, "truth": truth.get(img.stem)}
             for m in models for img in images for r in range(args.runs)]
    random.shuffle(tasks)  # spread each model's calls over the whole run
    print(f"{len(tasks)} calls: {len(models)} models x {len(images)} images x {args.runs} runs")
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        records = list(pool.map(lambda t: call(t, key, prompt), tasks))

    with open(args.out, "w", encoding="utf-8") as fh:
        for r in records:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    summarize(records, models)
    print(f"\nPer-call records: {args.out}")


if __name__ == "__main__":
    main()
