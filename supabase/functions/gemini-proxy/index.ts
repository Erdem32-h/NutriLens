import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authorizeAndConsume, readBody, RequestError, validateBody } from "./request_guard.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_API_BASE =
  "https://generativelanguage.googleapis.com/v1beta/models";

// Pick the model per action. All vision OCR actions now run on Flash —
// Pro + dynamic thinking reliably exceeded the mobile client / gateway
// timeout window on dense ingredient labels (symptom: user saw "AI
// çalışmıyor" even though nutrition OCR on Flash returned fine). Flash
// with dynamic thinking keeps accuracy high enough for this workload
// while cutting wall time by ~3x. Preview snapshots (e.g.
// 2.5-flash-preview-05-20) underperform on vision tasks vs the current
// stable GA releases.
function modelFor(action: string): string {
  switch (action) {
    case "ocr_ingredients_image":
      // Flash is fast enough on ingredient text and was confirmed working
      // by user ("İçindekiler kısmı hızlandı").
      return "gemini-flash-latest";
    case "ocr_nutrition_image":
      // Flash. We tried `gemini-2.5-pro` in v31 and Gemini rejected the
      // request in <1s with a 502 (likely model-not-available / region /
      // quota for our project). Flash is the only model we know responds
      // 200 from this proxy. The all-null symptom in v30 came from the
      // nullable schema, not from Flash itself — see the schema-removal
      // note in this case's generationConfig.
      return "gemini-flash-latest";
    case "food_recognition":
      return "gemini-flash-latest";
    default:
      return "gemini-flash-latest";
  }
}

// ── OpenRouter (server-side vision: meal analysis + label OCR) ────────
// Meal analysis AND ingredients/nutrition image OCR are routed here instead
// of the client's direct provider call: the key lives server-side (no abuse /
// runaway credit drain) and the model is swappable via env. gpt-4.1-nano was
// the original cheap meal model, but it under-performed on portion/nutrition
// estimation — gemini-2.5-flash is the stronger default (still cheap).
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY");
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const OPENROUTER_MEAL_MODEL =
  Deno.env.get("OPENROUTER_MEAL_MODEL") ?? "google/gemini-2.5-flash";
// Label OCR (ingredients + nutrition) moved off the direct-Gemini key — that
// path was returning 502s (quota / model availability). Default model chosen
// by the 2026-07-22 A/B (21 runs, clean/rotated/degraded Turkish label):
// gemini-3.5-flash-lite produced byte-identical text to 2.5-flash at half
// the median latency (1.6 s vs 3.1 s server-side, no 16-18 s capacity
// spikes observed) and the same price. Roll back by setting the env var to
// google/gemini-2.5-flash — no redeploy needed.
const OPENROUTER_OCR_MODEL =
  Deno.env.get("OPENROUTER_OCR_MODEL") ?? "google/gemini-3.5-flash-lite";

// Models the anon-callable OCR actions may be switched to per request via
// `payload.model_override` — the A/B harness for latency/quality tests
// without redeploying or touching the default everyone else gets. Hard
// allowlist on purpose: this endpoint is reachable with the anon key, and a
// caller must never be able to point our OpenRouter spend at an expensive
// model. Every listed model is in the same cheap Flash tier.
const AB_TEST_OCR_MODELS = new Set([
  "google/gemini-2.5-flash",
  "google/gemini-3.5-flash-lite",
  "google/gemini-3.6-flash",
]);

function languageName(code?: string): string {
  switch ((code ?? "tr").toLowerCase()) {
    case "en":
      return "English";
    case "de":
      return "German";
    case "fr":
      return "French";
    case "es":
      return "Spanish";
    case "ar":
      return "Arabic";
    default:
      return "Turkish";
  }
}

// Kept in sync with AnthropicAiService._mealAnalysisPrompt (Dart). The schema
// MUST stay identical — the client reuses parseMealAnalysisResponseText.
function mealAnalysisPrompt(code?: string): string {
  const ln = languageName(code);
  return `Bu görseldeki öğünü analiz et. Amacın TEK KİŞİNİN yediği porsiyonu
gramaj + besin değeri olarak döndürmek.

Yanıt dili: ${ln}. food_name, ingredients_text ve description alanlarını
${ln} dilinde yaz (yemek adını da bu dile çevir; örn. İngilizce için
"Etli Pilav" -> "Rice with Meat").

ÖNEMLİ — önce yemeğin KAYNAĞINI belirle ve "food_source" alanına yaz:
- "homemade": evde pişmiş/hazırlanmış ev yapımı yemek.
- "packaged": paketli/markalı market ürünü (kutu, paket, şişe, teneke,
  kavanoz; üzerinde marka logosu, etiket veya barkod olan ambalajlı ürün).
- "restaurant": restoran/kafede servis edilen YA DA restorandan paket/eve
  sipariş edilen hazır yemek (restoran tabağı sunumu, take-away kabı/kutusu,
  paket servis ambalajı).
Emin değilsen "homemade" yaz. "packaged" ise kullanıcıya barkod okutması
önerilecek; yine de diğer alanları elinden geldiğince doldur.

Önce şu kararı ver:
1. BİREYSEL porsiyon mu? (Bir kişinin önünde duran, tek başına yeneceği
   bir kase/tabak.)
2. PAYLAŞIMLI tabak/tencere mi? (Ortaya konmuş büyük servis tabağı,
   tencere, börek tepsisi, pizza, meze platter'ı.)

PAYLAŞIMLI ise: Sadece BİR kişinin alacağı tipik porsiyonu hesapla
(yaklaşık 150-250 g). Tabaktaki toplam yemeği DEĞİL.
BİREYSEL ise: Görseldeki gerçek miktarı tahmin et.

Yiyecek tipi referans aralıkları (bir kişilik):
  * Ana yemek (et, balık, tavuk): 150-250 g
  * Pilav / makarna garnitür: 80-150 g
  * Pilav / makarna ana yemek: 200-300 g
  * Çorba: 250-350 ml
  * Salata / meze: 80-150 g
  * Sandviç / dürüm / börek: 150-250 g
  * Tatlı / pasta: 80-150 g
  * İçecek: 200-400 ml

Sert kurallar:
- 50 g'dan az veya 350 g'dan fazla TEK KİŞİLİK porsiyon DÖNDÜRME.
- Default olarak 100 g sabiti KULLANMA. Fotoğrafa ve yemek tipine bak.
- portion_grams: bir kişinin yediği toplam gramaj.
- nutrition: o porsiyonun TOPLAM besin değerleri (100 g için değil).
- İçindekileri (${ln}) düz metin olarak yaz.
- confidence: 0.0 ile 1.0 ARASINDA ondalık sayı (örn. 0.75). Yüzde (75) DEĞİL.
- Belirsizse yine en iyi tahmini yap, confidence düşük olur.
- Bulamadığın besin değerlerini 0 döndür.
- Sadece JSON döndür, açıklama veya markdown yazma.

Şema:
{
  "food_name": string,
  "portion_grams": number,
  "ingredients_text": string,
  "nutrition": {
    "energy_kcal": number, "fat": number, "saturated_fat": number,
    "trans_fat": number, "carbohydrates": number, "sugars": number,
    "salt": number, "fiber": number, "protein": number
  },
  "confidence": number,
  "description": string,
  "food_source": "homemade" | "packaged" | "restaurant"
}`;
}

// Kept in sync with AnthropicAiService._recalcNutritionPrompt (Dart).
function recalcNutritionPrompt(
  ingredientsText: string,
  portionNote?: string,
): string {
  const hasNote = !!portionNote && portionNote.trim().length > 0;
  const noteSection = hasNote
    ? `\nKullanıcı notu (porsiyon hakkında):\n${portionNote!.trim()}\n
Bu nota öncelik ver. "Yarım porsiyon" -> tek kişilik porsiyonun yarısı.
"300 g yedim" gibi açık gramaj varsa onu kullan.\n`
    : `\nKullanıcı porsiyon notu vermedi. İçeriğe uygun makul bir tek kişilik
porsiyon belirle ve onu hem portion_grams'ta dön hem değerleri ona göre
hesapla.\n`;
  return `Aşağıdaki içerik listesine göre tek kişilik bir öğünün tahmini besin
değerlerini hesapla.
${noteSection}
İçerik:
${ingredientsText}

Genel kurallar:
- portion_grams o porsiyonun toplam gramajıdır.
- nutrition değerleri o portion_grams için TOPLAM değerdir, 100 g için değil.
- Bulamadığın değerleri 0 döndür.
- Sadece JSON döndür, açıklama veya markdown yazma.

Şema:
{
  "portion_grams": number,
  "nutrition": {
    "energy_kcal": number, "fat": number, "saturated_fat": number,
    "trans_fat": number, "carbohydrates": number, "sugars": number,
    "salt": number, "fiber": number, "protein": number
  }
}`;
}

interface OpenRouterResult {
  ok: boolean;
  status: number;
  text: string;
  errBody: string;
  /// Wall time of the OpenRouter round trip, for the latency logs and the
  /// `duration_ms` field returned to the client.
  elapsedMs: number;
  completionTokens: number | null;
  /// Thinking tokens the provider spent (usage.completion_tokens_details).
  /// The direct evidence for whether a reasoning setting actually took —
  /// latency alone can't distinguish "thinking disabled" from "fast network".
  reasoningTokens: number | null;
}

async function callOpenRouter(
  messages: unknown[],
  maxTokens: number,
  opts: {
    model?: string;
    json?: boolean;
    temperature?: number;
    reasoning?: Record<string, unknown>;
  } = {},
): Promise<OpenRouterResult> {
  const body: Record<string, unknown> = {
    model: opts.model ?? OPENROUTER_MEAL_MODEL,
    max_tokens: maxTokens,
    temperature: opts.temperature ?? 0.2,
    messages,
  };
  // JSON mode for structured actions (meal/recalc/nutrition); plain text for
  // ingredients OCR (which returns a free-form list or the not-found sentinel).
  if (opts.json !== false) {
    body.response_format = { type: "json_object" };
  }
  // Thinking control. Left unset, Gemini-family models default to *dynamic*
  // thinking — the model decides per request how long to reason, which on
  // dense/blurry label photos dominates wall time (the 15-25 s tail) and is
  // billed at the output-token rate. OCR actions pass an explicit setting;
  // meal analysis deliberately keeps the provider default (portion estimation
  // is a genuine reasoning task).
  if (opts.reasoning) {
    body.reasoning = opts.reasoning;
  }
  // Ask OpenRouter to attach token accounting to the response. Without this
  // some providers omit completion_tokens_details, and reasoning_tokens is
  // the only ground truth for whether a reasoning setting actually reached
  // the model — latency alone can't tell "thinking off" from "quiet network".
  body.usage = { include: true };
  const startedAt = Date.now();
  const resp = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://nutrilenshq.com",
      "X-Title": "NutriLens",
    },
    body: JSON.stringify(body),
  });
  const raw = await resp.text();
  const elapsedMs = Date.now() - startedAt;
  if (!resp.ok) {
    return {
      ok: false,
      status: resp.status,
      text: "",
      errBody: raw.slice(0, 300),
      elapsedMs,
      completionTokens: null,
      reasoningTokens: null,
    };
  }
  let content = "";
  let completionTokens: number | null = null;
  let reasoningTokens: number | null = null;
  try {
    const parsed = JSON.parse(raw);
    content = parsed?.choices?.[0]?.message?.content ?? "";
    completionTokens = parsed?.usage?.completion_tokens ?? null;
    reasoningTokens =
      parsed?.usage?.completion_tokens_details?.reasoning_tokens ?? null;
  } catch (_) {
    // leave content empty; caller treats empty as a failure
  }
  return {
    ok: true,
    status: resp.status,
    text: content,
    errBody: "",
    elapsedMs,
    completionTokens,
    reasoningTokens,
  };
}

// ── Provider-auth alerting ────────────────────────────────────────────
// The failure class that silently kills every AI feature at once: OpenRouter
// refusing our credentials — key disabled or deleted (401), balance spent
// (402), key forbidden (403). On 2026-09-12 a disabled key went unnoticed for
// two days because the only place it surfaced was the user's own error
// screen. Transient statuses (429, 5xx) are deliberately NOT alerted: they
// recover by themselves and would bury the signal that needs a human.
//
// Reported to Sentry with a plain fetch — the store endpoint is a single POST,
// so pulling in an SDK would cost a cold-start for nothing. Sentry groups by
// fingerprint, so a multi-day outage stays one issue however many calls hit it.
const SENTRY_DSN = Deno.env.get("SENTRY_DSN");

async function alertProviderAuthFailure(
  action: string,
  status: number,
  errBody: string,
): Promise<void> {
  if (!SENTRY_DSN || (status !== 401 && status !== 402 && status !== 403)) {
    return;
  }
  // DSN shape: https://<publicKey>@<host>/<projectId>
  const m = /^https:\/\/([^@]+)@([^/]+)\/(.+)$/.exec(SENTRY_DSN);
  if (!m) {
    console.error("[alert] SENTRY_DSN is malformed; no alert sent");
    return;
  }
  const [, publicKey, host, projectId] = m;
  const reason = status === 402 ? "balance spent" : "key rejected";
  try {
    const resp = await fetch(`https://${host}/api/${projectId}/store/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Sentry-Auth":
          `Sentry sentry_version=7, sentry_client=gemini-proxy/1, ` +
          `sentry_key=${publicKey}`,
      },
      body: JSON.stringify({
        event_id: crypto.randomUUID().replaceAll("-", ""),
        timestamp: new Date().toISOString(),
        platform: "other",
        level: "error",
        logger: "gemini-proxy",
        server_name: "supabase-edge",
        // One issue for the whole outage regardless of which action tripped it.
        fingerprint: ["openrouter-auth-failure"],
        message: `OpenRouter ${status} (${reason}) — every AI action is down ` +
          `until OPENROUTER_API_KEY is fixed`,
        tags: { provider: "openrouter", status: String(status), action },
        extra: { body: errBody.slice(0, 300) },
      }),
    });
    if (!resp.ok) {
      console.error(`[alert] sentry store status=${resp.status}`);
    }
  } catch (e) {
    // Alerting must never turn a provider outage into a 500.
    console.error(`[alert] sentry threw=${e}`);
  }
}

// ── Direct-Gemini fallback for the OpenRouter actions ─────────────────
// OpenRouter is a single point of failure: one dead key or a spent balance
// takes meal analysis AND label OCR down together (2026-09-12 outage — every
// call came back 401 "User not found", both features dark until the secret
// was replaced). On an OpenRouter failure we retry the identical prompt once
// against the direct Gemini key: a separate vendor account with separate
// billing, so the two are unlikely to die at the same moment. This is not
// load balancing — one extra call, only after a failure. Returns null when
// the fallback is unconfigured or also fails, and the caller then keeps its
// existing error response.
async function callGeminiFallback(
  action: string,
  promptText: string,
  imageBase64: string | undefined,
  opts: { json: boolean; maxTokens: number; temperature: number },
): Promise<string | null> {
  if (!GEMINI_API_KEY) return null;
  const parts: Record<string, unknown>[] = [{ text: promptText }];
  if (imageBase64) {
    parts.push({ inlineData: { mimeType: "image/jpeg", data: imageBase64 } });
  }
  const generationConfig: Record<string, unknown> = {
    maxOutputTokens: opts.maxTokens,
    temperature: opts.temperature,
  };
  // Mirrors OpenRouter's response_format:json_object. Deliberately no
  // responseSchema — the nullable schema tried in v30 is what produced the
  // all-null nutrition results; plain JSON mode does not have that failure.
  if (opts.json) generationConfig.responseMimeType = "application/json";
  const model = modelFor(action);
  const startedAt = Date.now();
  // Two attempts, not one. Measured on 2026-09-12: gemini-flash-latest
  // returns 503 UNAVAILABLE ("currently experiencing high demand") on a large
  // share of calls — a capacity blip on Google's side, not our quota or key,
  // and the immediate retry succeeds. Retrying only the transient statuses
  // keeps a hard failure (401/400) from costing a second round trip.
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const resp = await fetch(
        `${GEMINI_API_BASE}/${model}:generateContent?key=${GEMINI_API_KEY}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ contents: [{ parts }], generationConfig }),
        },
      );
      if (!resp.ok) {
        const retriable = resp.status === 503 || resp.status === 429 ||
          resp.status === 500;
        console.error(
          `[gemini-fallback ${action}] model=${model} attempt=${attempt} ` +
            `status=${resp.status} body=${(await resp.text()).slice(0, 300)}`,
        );
        if (retriable && attempt === 1) {
          await new Promise((r) => setTimeout(r, 600));
          continue;
        }
        return null;
      }
      const data = await resp.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof text !== "string" || !text.trim()) {
        console.error(
          `[gemini-fallback ${action}] model=${model} attempt=${attempt} ` +
            `empty response`,
        );
        return null;
      }
      console.log(
        `[gemini-fallback ${action}] model=${model} ok attempt=${attempt} ` +
          `elapsed_ms=${Date.now() - startedAt}`,
      );
      return text;
    } catch (e) {
      console.error(
        `[gemini-fallback ${action}] model=${model} attempt=${attempt} threw=${e}`,
      );
      if (attempt === 1) continue;
      return null;
    }
  }
  return null;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
// The legacy anon JWT that shipped app builds still send. See the
// legacyAnonKey note in request_guard.ts — without this, every guest scan
// 401s the moment the project starts injecting the publishable key.
const LEGACY_ANON_KEY = Deno.env.get("AI_LEGACY_ANON_KEY");

interface RequestBody {
  action:
    | "ocr_ingredients"
    | "ocr_ingredients_image"
    | "ocr_nutrition"
    | "ocr_nutrition_image"
    | "food_recognition"
    | "meal_analysis"
    | "recalc_nutrition"
    | "classify_category";
  payload: {
    text?: string;
    image_base64?: string;
    language_code?: string;
    ingredients_text?: string;
    product_name?: string;
    portion_note?: string;
    // Hashed device id — required for the anon-allowed OpenRouter actions so
    // they can be rate-limited per device without a user JWT.
    device_hash?: string;
    // Optional OCR model override for A/B testing. Ignored unless it is in
    // AB_TEST_OCR_MODELS; never applies to meal analysis.
    model_override?: string;
  };
}

/// Handles the anon-allowed OpenRouter actions: meal analysis, recalc, and
/// (since the direct-Gemini key started 502ing) ingredients + nutrition image
/// OCR. The request guard has already authenticated the caller and consumed
/// the persistent subject/global quota before entering this provider path.
async function handleOpenRouterAction(
  action:
    | "meal_analysis"
    | "recalc_nutrition"
    | "ocr_ingredients_image"
    | "ocr_nutrition_image",
  payload: RequestBody["payload"],
): Promise<Response> {
  const jsonHeaders = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  };
  if (!OPENROUTER_API_KEY) {
    return new Response(
      JSON.stringify({ error: "OpenRouter API key not configured" }),
      { status: 500, headers: jsonHeaders },
    );
  }

  // Helper: a single user turn carrying prompt text + the JPEG image.
  const imageMessage = (text: string) => [
    {
      role: "user",
      content: [
        { type: "text", text },
        {
          type: "image_url",
          image_url: { url: `data:image/jpeg;base64,${payload.image_base64}` },
        },
      ],
    },
  ];
  const missingImage = () =>
    new Response(JSON.stringify({ error: "Missing image" }), {
      status: 400,
      headers: jsonHeaders,
    });

  // The prompt is kept as plain text (not pre-wrapped in OpenRouter message
  // shape) so the Gemini fallback below can re-send the exact same prompt.
  let promptText: string;
  let useImage = true;
  let maxTokens: number;
  let model = OPENROUTER_MEAL_MODEL;
  let json = true;
  let temperature = 0.2;
  let reasoning: Record<string, unknown> | undefined;

  if (action === "meal_analysis") {
    if (!payload.image_base64) return missingImage();
    promptText = mealAnalysisPrompt(payload.language_code);
    maxTokens = 1000;
  } else if (action === "recalc_nutrition") {
    if (!payload.ingredients_text) {
      return new Response(
        JSON.stringify({ error: "Missing ingredients_text" }),
        { status: 400, headers: jsonHeaders },
      );
    }
    promptText = recalcNutritionPrompt(
      payload.ingredients_text,
      payload.portion_note,
    );
    useImage = false;
    maxTokens = 700;
  } else {
    // ocr_ingredients_image | ocr_nutrition_image — reuse the exact Gemini
    // prompt text (single source of truth in buildPrompt) but send it through
    // OpenRouter so the label pipeline doesn't depend on the direct-Gemini key.
    if (!payload.image_base64) return missingImage();
    const built = buildPrompt(action, payload) as {
      contents: { parts: { text?: string }[] }[];
    };
    promptText = built.contents?.[0]?.parts?.[0]?.text ?? "";
    model = OPENROUTER_OCR_MODEL;
    // Allowlisted per-request override — see AB_TEST_OCR_MODELS. Unknown
    // values fall through to the default silently rather than erroring, so
    // an old test script can never take the OCR path down.
    if (
      payload.model_override &&
      AB_TEST_OCR_MODELS.has(payload.model_override)
    ) {
      model = payload.model_override;
    }
    temperature = 0;
    if (action === "ocr_ingredients_image") {
      json = false; // free-form list or the İÇİNDEKİLER_BULUNAMADI sentinel
      // 2048, down from 4096. Two reasons: (1) the longest real multi-section
      // label + allergen block measures ~600 output tokens, so 2048 is still
      // 3x headroom; (2) OpenRouter pre-authorizes a request against the
      // account balance using max_tokens as the ceiling — at 4096 a low
      // balance 402s this action while the 1024-token nutrition action still
      // passes, which is exactly the outage observed on 2026-07-22.
      maxTokens = 2048;
      // Reading a label verbatim is transcription, not reasoning — pin
      // thinking to the floor. The floor is model-generation-specific:
      //  - Gemini 2.5: `enabled:false` turns thinking fully off (verified
      //    reasoning_tokens=0). `effort:"none"` is silently IGNORED, and a
      //    positive budget turns thinking ON — both measured, both wrong.
      //  - Gemini 3.x: thinking cannot be disabled at all; sending
      //    `enabled:false` gets the whole request 400'd by OpenRouter
      //    (measured in the 2026-07-22 A/B). `effort:"minimal"` maps to
      //    Google's thinkingLevel=minimal, the lowest valid setting.
      reasoning = model.startsWith("google/gemini-3")
        ? { effort: "minimal" }
        : { enabled: false };
    } else {
      json = true; // strict nutrition JSON object
      maxTokens = 1024;
      // Deliberately NO reasoning override: v40 tried a fixed 512-token
      // budget and the model started returning quantities as JSON *strings*
      // ("518" instead of 518) — which the Dart parser rejects — while
      // also getting slower (fixed budgets are spent; dynamic thinking on
      // an easy table is brief). Provider-default dynamic thinking is both
      // the accuracy-proven and the empirically faster setting here.
    }
  }

  const messages = useImage
    ? imageMessage(promptText)
    : [{ role: "user", content: promptText }];

  const or = await callOpenRouter(messages, maxTokens, {
    model,
    json,
    temperature,
    reasoning,
  });
  if (!or.ok || !or.text) {
    console.error(
      `[openrouter ${action}] model=${model} ` +
        `status=${or.status} body=${or.errBody}`,
    );
    await alertProviderAuthFailure(action, or.status, or.errBody);
    const fallbackText = await callGeminiFallback(
      action,
      promptText,
      useImage ? payload.image_base64 : undefined,
      { json, maxTokens, temperature },
    );
    if (fallbackText) {
      return new Response(
        JSON.stringify({
          result: fallbackText,
          action,
          // Tells a log reader (and any future client-side banner) that this
          // answer did not come from the primary provider.
          provider: "gemini-fallback",
          openrouter_status: or.status,
        }),
        { status: 200, headers: jsonHeaders },
      );
    }
    const clientStatus = or.status === 402 || or.status === 429 ? 429 : 502;
    return new Response(
      JSON.stringify({ error: "AI service error", openrouter_status: or.status }),
      { status: clientStatus, headers: jsonHeaders },
    );
  }
  // One line per successful call: the before/after latency evidence lives in
  // the function logs, not in a dashboard we'd have to build. reasoning_tokens
  // is the ground truth that a reasoning setting actually took effect.
  console.log(
    `[openrouter ${action}] model=${model} elapsed_ms=${or.elapsedMs} ` +
      `completion_tokens=${or.completionTokens ?? "?"} ` +
      `reasoning_tokens=${or.reasoningTokens ?? "?"}`,
  );
  return new Response(
    // duration_ms: server-side wall time of the model call — lets the client
    // (and the measurement script) separate "model was slow" from "my mobile
    // connection was slow". The token counts serve the same diagnostic role
    // for cost: reasoning_tokens shows whether thinking ran on this call.
    JSON.stringify({
      result: or.text,
      action,
      duration_ms: or.elapsedMs,
      completion_tokens: or.completionTokens,
      reasoning_tokens: or.reasoningTokens,
    }),
    { status: 200, headers: jsonHeaders },
  );
}

function buildPrompt(action: string, payload: RequestBody["payload"]): object {
  switch (action) {
    case "ocr_ingredients":
      return {
        contents: [
          {
            parts: [
              {
                text: `Sen bir gıda etiketi uzmanısın. Aşağıdaki metin bir gıda ürününün içindekiler listesinin OCR çıktısıdır.

ÖNEMLİ KURALLAR:
1. Türkçe karakterleri MUTLAKA doğru yaz: ş, ğ, ı, İ, ü, ö, ç. OCR bu karakterleri genellikle ASCII'ye dönüştürür (örn. "seker"→"şeker", "yag"→"yağ", "sut"→"süt", "cikolata"→"çikolata", "findik"→"fındık"). Tüm bu hataları düzelt.
2. SADECE içindekiler listesini döndür. Şunları kesinlikle EKLEME:
   - Saklama koşulları ("Buzdolabında sakla", "18-22°C'de muhafaza ediniz" vb.)
   - Son tüketim / üretim tarihi / TETT / Parti No
   - Üretici firma adı ve adresi
   - Türk standart numaraları (TS xxxx)
   - Web sitesi adresleri
   - "Dikkat!", "Uyarı:" blokları
3. İçindekiler listesi genellikle "içerebilir" veya "içerir" kelimesiyle biter — buradan sonrasını alma.
4. Temiz, virgülle ayrılmış tek satır liste döndür.
5. SADECE Türkçe içindekileri al. Çok dilli etiketlerde (örn. TR + Azerice, TR + İngilizce) diğer dillerdeki içindekiler listelerini ALMA. Azerice işaretleri: "Tarkibi:", "İstehsalçı", "saxlanma", "AZ" ülke kodu. Bunları ve sonrasını dahil etme.
6. Eğer metin Türkçe ise Türkçe yaz, başka bir dilde ise Türkçeye çevir.

OCR metni:
${payload.text}

Sadece düzeltilmiş Türkçe içindekiler listesini döndür, başka hiçbir şey yazma.`,
              },
            ],
          },
        ],
      };

    case "ocr_ingredients_image":
      return {
        contents: [
          {
            parts: [
              {
                text: `Bu bir gıda paketinin fotoğrafı. Görevin: paketteki "İçindekiler:" başlığı altındaki listeyi (alt-listeler ve alerjen uyarıları dahil) EKSİKSİZ olarak harfi harfine okumak.

ÖNCE BUL, SONRA OKU:
- Önce fotoğrafta "İçindekiler:" / "İçindekiler" başlığını bul. Bu başlık YOKSA, kararını ver: SADECE şu tek kelimeyi döndür: İÇİNDEKİLER_BULUNAMADI
- Başlığı bulduysan, başlıktan sonraki listeyi sonuna kadar (alerjen uyarıları veya besin değerleri tablosuna kadar) oku.

NE İÇİNDEKİLER DEĞİLDİR (asla bunları içindekiler diye döndürme):
- Üretici/firma adı ve adres (sokak adı, mahalle, ilçe, "Cad.", "Sok.", "Mah.", posta kodu, telefon, e-posta, web sitesi)
- "Üretici:", "İthalatçı:", "Dağıtıcı:", "İletişim:", "Adres:" blokları
- Besin değerleri tablosu (Enerji, Yağ, Karbonhidrat, Protein satırları)
- Son tüketim tarihi, üretim tarihi, TETT, parti no, barkod, TS xxxx kodu
- Saklama koşulları, "Helal" damgası, sertifika logoları
- Sadece bunları görüyorsan ve "İçindekiler:" başlığı yoksa: İÇİNDEKİLER_BULUNAMADI

ÇIKTI YAPISI:
- Birden fazla bölüm/ürün varsa (örn. "Kakaolu Fındık Kremalı Bisküvi Bölümü:", "Sade Bisküvi Bölümü:"), her bölümü kendi başlığıyla ayrı paragraf olarak yaz.
- Bir bileşenin alt-içindekileri parantez veya köşeli parantez içindeyse AYNEN koru (örn. "Kakaolu Fındıklı Krema (%36): [Şeker, Bitkisel Yağ (Palm), ...]").
- Alerjen uyarılarını AYRI bir paragraf olarak ekle. Format:
  "Alerjen Uyarıları:
  İçerir: ...
  Eser Miktarda İçerebilir: ..."

KURALLAR:
1. Türkçe karakterleri MUTLAKA doğru yaz: ş, ğ, ı, İ, ü, ö, ç. ASCII'ye dönüştürme.
2. Yüzdeleri (%X, %X,X), parantezleri, köşeli parantezleri AYNEN koru.
3. SADECE Türkçe bölümünü al. Çok dilli etikette diğer dilleri (Azerice "Tərkibi", "ə" harfi, "İstehsalçı"; İngilizce "Ingredients") ATLA.
4. Listeyi BAŞINDAN SONUNA kadar oku — ilk birkaç maddeyi atlama. "İçindekiler:" başlığından sonraki HER ŞEY listenin parçasıdır.
5. Fotoğraf dönük (90°/180°/270°), eğri, parlak ya da yan çekilmişse metni zihninde döndürerek/düzelterek oku. Yan çekilen fotoğraflarda paketi mental olarak çevir ve doğru bölüme bak.
6. Aroma/katkı isimlerini doğru oku — uydurma yapma. Örn: "doğala özdeş aromalar" yerine etikette ne yazıyorsa onu yaz ("Aroma Vericiler", "Aroma" vb.). Tahmin etme — okunmayan kısmı atla, yerine üretici/adres metni KOYMA.
7. Yorum, açıklama, markdown veya boş satırla başlama — direkt içindekiler metnini döndür.`,
              },
              {
                inlineData: {
                  mimeType: "image/jpeg",
                  data: payload.image_base64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
          topP: 0.95,
          maxOutputTokens: 4096,
        },
      };

    case "ocr_nutrition_image":
      return {
        contents: [
          {
            parts: [
              {
                text: `Bu bir gıda paketinin fotoğrafı. Görevin: paketteki "Besin Değerleri" / "Besin Değerleri Tablosu" / "Nutrition Facts" tablosunu OKUMAK ve 100g başına değerleri JSON olarak döndürmek.

ÖNCE BUL, SONRA OKU:
- Önce fotoğrafta besin değerleri tablosunu bul (Enerji/kJ/kcal/Yağ/Karbonhidrat satırları olan blok).
- Tablo YOKSA tüm alanları null yap.

NE TABLODA OLMAYAN BİR ŞEY ALMA:
- İçindekiler listesini ALMA.
- Üretici/firma/adres bloklarını ALMA.
- Saklama, son tüketim, parti no bilgilerini ALMA.

DEĞER OKUMA KURALLARI:
1. Tüm değerler 100g (ya da 100ml) başına olmalı. Etikette hem "100g başına" hem de "porsiyon başına" sütunu varsa, MUTLAKA "100g" sütununu al.
2. Türk etiketlerinde enerji çoğunlukla "2289 kJ / 549 kcal" formatındadır. Sadece kcal değerini (eğik çizgiden sonraki sayıyı) "energy_kcal" olarak ver.
3. Birim dönüşümü: mg → g (değeri 1000'e böl). µg/mcg → g (1.000.000'a böl).
4. Ondalık ayırıcı virgül ise noktaya çevir (örn. "0,60" → 0.60).
5. Etikette "Tuz" yoksa ama "Sodyum" varsa: salt = sodium * 2.5 (gram cinsinden).
6. Etikette satır VAR ama değer "<0.5g" veya "iz miktar" gibi yazıyorsa, 0 olarak değil, gerçek değer okunamadığı için null olarak ver.
7. Etikette satır YOK (hiç yazmıyor) → null.
8. Etikette satır VAR ve değer "0" / "0g" / "0.0g" yazıyor → 0 olarak ver (null DEĞİL).
9. Trans yağ satırı çoğu etikette yer alır ve sıfırdır — gözden kaçırma, "Doymuş Yağ" satırının hemen altına bak.

ÇIKTI: SADECE şu JSON formatında döndür, başka hiçbir şey (markdown, açıklama, yorum) yazma:
{"energy_kcal":null,"fat":null,"saturated_fat":null,"trans_fat":null,"carbohydrates":null,"sugars":null,"salt":null,"fiber":null,"protein":null}`,
              },
              {
                inlineData: {
                  mimeType: "image/jpeg",
                  data: payload.image_base64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
          topP: 0.95,
          maxOutputTokens: 1024,
          // Dynamic thinking — Flash without thinking misread Turkish
          // nutrition tables (mg→g conversions, kJ/kcal dual format,
          // 100g-vs-portion column choice). With thinking on, Flash got
          // it right in the lab during the original v16-era tests.
          thinkingConfig: {
            thinkingBudget: -1,
          },
          // JSON mode — guarantees parseable output without a schema.
          // The schema attempt (v30, all fields nullable) backfired: Flash
          // took the easy route and filled every field with null. The
          // prompt's literal JSON template carries the same shape
          // information without permitting the all-null escape hatch.
          responseMimeType: "application/json",
        },
      };

    case "classify_category": {
      const name = (payload.product_name ?? "").toString().slice(0, 120);
      const ingredients = (payload.ingredients_text ?? "")
        .toString()
        .slice(0, 600);
      const ids = [
        "sut", "yogurt", "peynir", "yag", "biskuvi", "cikolata", "sekerleme",
        "cips", "kuruyemis", "gazli_icecek", "meyve_suyu", "su", "kahve_cay",
        "ekmek", "gevrek", "makarna", "hazir_yemek", "sos", "recel_bal",
        "et_sarkuteri", "dondurma", "diger",
      ].join(", ");
      return {
        contents: [
          {
            parts: [
              {
                text:
                  `Bir gıda ürününü tek bir kategoriye sınıflandır.\n` +
                  `Ürün adı: ${name}\nİçindekiler: ${ingredients}\n\n` +
                  `SADECE şu id'lerden BİRİNİ döndür (başka hiçbir şey yazma): ${ids}.\n` +
                  `Emin değilsen 'diger' yaz.`,
              },
            ],
          },
        ],
        generationConfig: { temperature: 0, maxOutputTokens: 12 },
      };
    }

    case "ocr_nutrition":
      return {
        contents: [
          {
            parts: [
              {
                text: `Sen bir gıda etiketi uzmanısın. Aşağıdaki metin bir besin değerleri tablosunun OCR çıktısıdır.

ÖNEMLİ FORMAT KURALLARI:
- Türk etiketlerinde enerji genellikle "2289 kJ / 549 kcal" şeklinde çift değer gösterir. Sadece kcal değerini (eğik çizgiden sonraki değer) al.
- Birimleri gram'a çevir: mg → g (/1000)
- Tüm değerler 100g başına olmalı
- Değer yoksa null yaz, sıfır yazma

Örnekler:
  "Enerji 2289kJ/549kcal" → energy_kcal: 549
  "Yağ 34g" → fat: 34
  "Doymuş Yağ 18g" → saturated_fat: 18
  "Trans Yağ 0g" → trans_fat: 0
  "Karbonhidrat 50g" → carbohydrates: 50
  "Şekerler 40g" → sugars: 40
  "Lif 4.0g" → fiber: 4.0
  "Protein 9.0g" → protein: 9.0
  "Tuz 0.60g" → salt: 0.60

OCR metni:
${payload.text}

Sadece şu JSON formatında döndür, başka bir şey yazma:
{"energy_kcal":null,"fat":null,"saturated_fat":null,"trans_fat":null,"carbohydrates":null,"sugars":null,"salt":null,"fiber":null,"protein":null}`,
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
          topP: 0.95,
          maxOutputTokens: 1024,
          responseMimeType: "application/json",
        },
      };

    case "food_recognition":
      return {
        contents: [
          {
            parts: [
              {
                text: `Sen bir beslenme uzmanısın. Bu fotoğraftaki yemeği analiz et.

Görevlerin:
1. Yemeğin ne olduğunu belirle (Türkçe isim, örn: "Mercimek Çorbası", "Tavuk Döner", "Karışık Salata")
2. Tahmini porsiyon büyüklüğü (gram cinsinden tek bir sayı)
3. Kalori ve makro besin değerlerini tahmin et (FOTOĞRAFTAKİ PORSİYON İÇİN, 100g başına DEĞİL)
4. confidence: 0.0-1.0 arası, yemeği tanıma kesinliğin
5. description: kısa 1-2 cümle açıklama (içerik, pişirme yöntemi)

Fotoğrafta yemek yoksa veya tanıyamıyorsan confidence'ı 0.0 yap ve food_name'i "Tanınamadı" olarak ver.

SADECE geçerli JSON döndür. Markdown, yorum, başlık YOK. Tüm sayılar sayı olmalı (string değil, null değil — bilinmiyorsa 0).`,
              },
              {
                inlineData: {
                  mimeType: "image/jpeg",
                  data: payload.image_base64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.2,
          topP: 0.95,
          maxOutputTokens: 1024,
          // Force JSON — no markdown fences, no narrative preface.
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              food_name: { type: "string" },
              portion_grams: { type: "integer" },
              energy_kcal: { type: "number" },
              fat: { type: "number" },
              saturated_fat: { type: "number" },
              sugars: { type: "number" },
              salt: { type: "number" },
              fiber: { type: "number" },
              protein: { type: "number" },
              confidence: { type: "number" },
              description: { type: "string" },
            },
            required: [
              "food_name",
              "portion_grams",
              "energy_kcal",
              "fat",
              "saturated_fat",
              "sugars",
              "salt",
              "fiber",
              "protein",
              "confidence",
              "description",
            ],
          },
        },
      };

    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    if (req.method !== "POST") throw new RequestError(405, "Method not allowed");
    const parsed = validateBody(await readBody(req));
    const limit = Number(Deno.env.get("AI_GLOBAL_DAILY_LIMIT"));
    if (!Number.isInteger(limit) || limit < 1 || limit > 100000) {
      throw new RequestError(503, "AI quota is not configured");
    }
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceKey) throw new RequestError(503, "AI quota is not configured");
    const admin = createClient(SUPABASE_URL, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    await authorizeAndConsume(req.headers.get("Authorization"), parsed, {
      anonKey: SUPABASE_ANON_KEY,
      legacyAnonKey: LEGACY_ANON_KEY,
      async getUser(token) {
        const { data, error } = await admin.auth.getUser(token);
        return error ? null : data.user?.id ?? null;
      },
      async consume(subject) {
        const { data, error } = await admin.rpc("consume_ai_quota", {
          p_subject: subject, p_global_daily_limit: limit,
        });
        if (error) throw new RequestError(503, "AI quota temporarily unavailable");
        return data === true;
      },
    });
    const { action, payload } = parsed;
    if (action === "meal_analysis" || action === "recalc_nutrition" ||
        action === "ocr_ingredients_image" || action === "ocr_nutrition_image") {
      return await handleOpenRouterAction(action, payload);
    }
    // Validate API key
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "Gemini API key not configured" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Build and send Gemini request
    const geminiPayload = buildPrompt(action, payload);
    const model = modelFor(action);
    const geminiUrl = `${GEMINI_API_BASE}/${model}:generateContent`;

    const response = await fetch(`${geminiUrl}?key=${GEMINI_API_KEY}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(geminiPayload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      // Log the model + first 500 chars of the error body so post-mortem
      // diagnosis doesn't need a fresh deploy. Truncated to keep the log
      // line bounded — Gemini error bodies can be huge with full request
      // echoes attached.
      console.error(
        `[gemini ${action}] model=${model} status=${response.status} ` +
          `body=${errorText.slice(0, 500)}`
      );
      return new Response(
        JSON.stringify({
          error: "AI service error",
          // Surface a short hint to the client too — only the status code
          // and a short snippet, never raw bodies that could leak the API
          // key prompt or PII.
          gemini_status: response.status,
        }),
        {
          status: 502,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const data = await response.json();
    const generatedText = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    return new Response(JSON.stringify({ result: generatedText, action }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    if (error instanceof RequestError) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: error.status, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }
    console.error("Edge function request failed");
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
