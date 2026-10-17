# AI vision model bake-off

Compare candidate OpenRouter vision models for meal analysis using the
**exact production request**: the prompt is read straight out of
`supabase/functions/gemini-proxy/index.ts` (`mealAnalysisPrompt`) and the
message shape + params mirror `handleOpenRouterAction`, so the eval cannot
drift from what users get.

## Setup

Add to `tools/ai_eval/.env` (NOT the project-root `.env` — that one is bundled
into the app as a Flutter asset via `pubspec.yaml`, so anything added there
ships inside the APK/IPA):

```
OPENROUTER_API_KEY=sk-or-...   # a separate, spend-limited eval key
```

## Run

```bash
# a folder of food photos (resize like the app: 2048 px long edge, JPEG q90)
python tools/ai_eval/compare_vision.py path/to/photos --runs 2 --out results.jsonl
# subset of models:
python tools/ai_eval/compare_vision.py path/to/photos --models google/gemini-2.5-flash,google/gemini-2.5-flash-lite
```

Optional `ground_truth.json` in the photo folder scores every answer:

```json
{"04_iskender": {"label": "İskender kebap", "accept": ["iskender"], "food_source": ["restaurant"]}}
```

Output: per-model summary (ok, dish recognised, food_source match, strict
schema, p50/p90/max latency, OpenRouter-billed $/call, tokens) plus a JSONL
record per call.

## How to read it

- **dish** — the whole feature rides on recognising the dish.
- **ok** — a model that returns no usable JSON is unusable regardless of price
  (in production it silently falls through to the direct-Gemini fallback).
- **p90 s** — the tail is what users feel.
- **$/call** — billed by OpenRouter (`usage.cost`), not estimated.

## Gotcha: reasoning models

With production params unchanged (`max_tokens: 1000`), reasoning models can
spend the entire budget thinking and return empty content (measured
2026-10-17: Claude Haiku 5.5 1000/1000 reasoning tokens, gpt-5-nano 960/1000).
`MODEL_OVERRIDES` in the script turns reasoning off for those; switching such
a model into production needs the same change in the edge function, not just
`OPENROUTER_MEAL_MODEL`.

## Eval set

`eval_set/` holds `ground_truth.json`, `sources.json` and the dated results.
The photos themselves are git-ignored (mostly CC BY-SA, Wikimedia Commons):
download each from its `page` in `sources.json` and save it as
`<key>.jpg`; `10_makarna_bolonez` is a copy of
`assets/images/onboarding_meal.jpg`.

## Results

- 2026-10-17 (11 photos x 2 runs): see NutriLens decisions log in the vault.
