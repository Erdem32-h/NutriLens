import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

// ── OpenRouter (cheap vision meal analysis) ───────────────────────────
// Signed-in users' meal analysis is routed here instead of the client's
// direct Anthropic call: the key lives server-side (no abuse / runaway
// credit drain), the model is swappable via env, and gpt-4.1-nano matched
// or beat Claude in our bake-off at ~37x lower cost.
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY");
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const OPENROUTER_MEAL_MODEL =
  Deno.env.get("OPENROUTER_MEAL_MODEL") ?? "openai/gpt-4.1-nano";

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
  "description": string
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
}

async function callOpenRouter(
  messages: unknown[],
  maxTokens: number,
): Promise<OpenRouterResult> {
  const resp = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://nutrilenshq.com",
      "X-Title": "NutriLens",
    },
    body: JSON.stringify({
      model: OPENROUTER_MEAL_MODEL,
      max_tokens: maxTokens,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages,
    }),
  });
  const raw = await resp.text();
  if (!resp.ok) {
    return { ok: false, status: resp.status, text: "", errBody: raw.slice(0, 300) };
  }
  let content = "";
  try {
    content = JSON.parse(raw)?.choices?.[0]?.message?.content ?? "";
  } catch (_) {
    // leave content empty; caller treats empty as a failure
  }
  return { ok: true, status: resp.status, text: content, errBody: "" };
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Rate limiting: simple in-memory store (resets on cold start)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 30; // requests per hour per user
const RATE_WINDOW_MS = 60 * 60 * 1000; // 1 hour

interface RequestBody {
  action:
    | "ocr_ingredients"
    | "ocr_ingredients_image"
    | "ocr_nutrition"
    | "ocr_nutrition_image"
    | "food_recognition"
    | "meal_analysis"
    | "recalc_nutrition";
  payload: {
    text?: string;
    image_base64?: string;
    language_code?: string;
    ingredients_text?: string;
    portion_note?: string;
    // Hashed device id — required for the anon-allowed OpenRouter actions so
    // they can be rate-limited per device without a user JWT.
    device_hash?: string;
  };
}

/// Handles the anon-allowed OpenRouter actions (cheap meal analysis + recalc).
/// Gated by a per-device-hash rate limit instead of user auth; the real cost
/// ceiling is the OpenRouter spend cap. Returns the proxied result or an error.
async function handleOpenRouterAction(
  action: "meal_analysis" | "recalc_nutrition",
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

  const deviceHash = payload.device_hash;
  if (!deviceHash || deviceHash.length < 16) {
    return new Response(JSON.stringify({ error: "Missing device_hash" }), {
      status: 400,
      headers: jsonHeaders,
    });
  }
  if (!checkRateLimit(`dev:${deviceHash}`)) {
    return new Response(
      JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
      { status: 429, headers: jsonHeaders },
    );
  }

  let messages: unknown[];
  let maxTokens: number;
  if (action === "meal_analysis") {
    if (!payload.image_base64) {
      return new Response(JSON.stringify({ error: "Missing image" }), {
        status: 400,
        headers: jsonHeaders,
      });
    }
    messages = [
      {
        role: "user",
        content: [
          { type: "text", text: mealAnalysisPrompt(payload.language_code) },
          {
            type: "image_url",
            image_url: {
              url: `data:image/jpeg;base64,${payload.image_base64}`,
            },
          },
        ],
      },
    ];
    maxTokens = 1000;
  } else {
    if (!payload.ingredients_text) {
      return new Response(
        JSON.stringify({ error: "Missing ingredients_text" }),
        { status: 400, headers: jsonHeaders },
      );
    }
    messages = [
      {
        role: "user",
        content: recalcNutritionPrompt(
          payload.ingredients_text,
          payload.portion_note,
        ),
      },
    ];
    maxTokens = 700;
  }

  const or = await callOpenRouter(messages, maxTokens);
  if (!or.ok || !or.text) {
    console.error(
      `[openrouter ${action}] model=${OPENROUTER_MEAL_MODEL} ` +
        `status=${or.status} body=${or.errBody}`,
    );
    const clientStatus = or.status === 402 || or.status === 429 ? 429 : 502;
    return new Response(
      JSON.stringify({ error: "AI service error", openrouter_status: or.status }),
      { status: clientStatus, headers: jsonHeaders },
    );
  }
  return new Response(JSON.stringify({ result: or.text, action }), {
    status: 200,
    headers: jsonHeaders,
  });
}

function checkRateLimit(userId: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(userId);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(userId, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return true;
  }

  if (entry.count >= RATE_LIMIT) {
    return false;
  }

  entry.count++;
  return true;
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

serve(async (req: Request) => {
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
    // Verify auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Parse early so anon-allowed actions route before the user-auth checks.
    const body: RequestBody = await req.json();
    const { action, payload } = body;
    if (!action || !payload) {
      return new Response(
        JSON.stringify({ error: "Missing action or payload" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Public (anon-allowed) cheap meal analysis + recalc. Guests have no user
    // JWT, so these are gated by a per-device-hash rate limit (+ the OpenRouter
    // spend cap) instead of user auth. The OCR/Gemini actions below still
    // require a signed-in user.
    if (action === "meal_analysis" || action === "recalc_nutrition") {
      return await handleOpenRouterAction(action, payload);
    }

    // Reject when the caller is sending the anon key instead of a user JWT.
    // We compare the raw bearer token against the project's anon key so we
    // can return a precise message ("you're not signed in") instead of the
    // misleading "Unauthorized" — and so the client can prompt re-login.
    const bearer = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (bearer === SUPABASE_ANON_KEY) {
      console.warn("[auth] anon key sent — user is not signed in");
      return new Response(
        JSON.stringify({
          error: "Not signed in",
          code: "anon_key_used",
        }),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData?.user) {
      console.warn(
        "[auth] getUser failed — bearer prefix=" +
          bearer.slice(0, 12) +
          "... err=" +
          (userError?.message ?? "no user")
      );
      return new Response(
        JSON.stringify({
          error: "Session expired",
          code: "invalid_jwt",
          details: userError?.message ?? "no user for token",
        }),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
    const user = userData.user;

    // Rate limit
    if (!checkRateLimit(user.id)) {
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
        {
          status: 429,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // `action` + `payload` were parsed and the public OpenRouter actions
    // already handled above (before user auth). Everything below requires a
    // signed-in user and goes to Gemini.

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

    if (action === "list_models") {
      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}`);
      const data = await response.json();
      return new Response(JSON.stringify(data), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
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

    // Diagnostic: surface what Gemini actually sent back for the nutrition
    // path so we can debug "all-null" symptoms without re-deploying. Cheap
    // (one log line per call), bounded (text is at most a few hundred
    // chars), and only fires for the action that's been flaky.
    if (action === "ocr_nutrition_image") {
      const finishReason = data?.candidates?.[0]?.finishReason;
      const promptTokens = data?.usageMetadata?.promptTokenCount;
      const respTokens = data?.usageMetadata?.candidatesTokenCount;
      const thinkTokens = data?.usageMetadata?.thoughtsTokenCount;
      console.log(
        `[ocr_nutrition_image] model=${model} finish=${finishReason} ` +
          `prompt_tok=${promptTokens} resp_tok=${respTokens} ` +
          `think_tok=${thinkTokens} text=${JSON.stringify(generatedText)}`
      );
    }

    return new Response(JSON.stringify({ result: generatedText, action }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
