# AI vision model bake-off

Compare candidate OpenRouter vision models against the Claude baseline for the
meal-analysis use case, using the **same prompt as production**
(`AnthropicAiService._mealAnalysisPrompt`).

## Setup

Add to the project-root `.env`:

```
OPENROUTER_API_KEY=sk-or-...
ANTHROPIC_API_KEY=sk-ant-...   # already present; used as the quality baseline
```

## Run

```bash
# put 3-5 real food photos in a folder, then:
python tools/ai_eval/compare_vision.py path/to/photos tr
# or English prompt:
python tools/ai_eval/compare_vision.py path/to/photos en
```

Output is a per-image table: `model | food_name | grams | kcal | confidence | seconds`.

## How to read it

- **Food name correct?** The whole feature rides on recognising the dish.
- **kcal sane?** Compare against Claude's number and reality.
- **Parse-fail?** A model that can't return clean JSON is unusable regardless
  of price — it breaks the app's parser.
- **Latency (s)?** Anything > ~25 s hurts UX.

Pick the cheapest model that gets the dish right and returns valid JSON on every
photo. That model id goes into the edge-function proxy (server-side, key-safe).

## Candidates

Edit `OPENROUTER_MODELS` in `compare_vision.py`. Current shortlist:
`meta-llama/llama-4-scout`, `qwen/qwen3-vl-8b-instruct`, `amazon/nova-lite-v1`,
`openai/gpt-4.1-nano`. Refresh the full live list any time with:

```bash
curl -s https://openrouter.ai/api/v1/models | python -c "import json,sys; \
[print(m['id']) for m in json.load(sys.stdin)['data'] \
if 'image' in (m.get('architecture',{}).get('input_modalities') or [])]"
```
