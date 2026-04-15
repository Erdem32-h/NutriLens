import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Rate limiting: simple in-memory store (resets on cold start)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT = 30; // requests per hour per user
const RATE_WINDOW_MS = 60 * 60 * 1000; // 1 hour

interface RequestBody {
  action: "ocr_ingredients" | "ocr_nutrition" | "food_recognition";
  payload: {
    text?: string;
    image_base64?: string;
  };
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
                text: `Sen bir gıda etiketi uzmanısın. Aşağıdaki metin bir gıda ürününün içindekiler listesinin OCR çıktısıdır. OCR hataları içerebilir.

Görevlerin:
1. OCR hatalarını düzelt (karakter karışıklıkları, eksik harfler)
2. Türkçe içerik varsa Türkçeyi tercih et
3. İngilizce ise Türkçeye çevir
4. Temiz, virgülle ayrılmış içindekiler listesi döndür

OCR metni: ${payload.text}

Sadece düzeltilmiş içindekiler listesini döndür, başka açıklama yazma.`,
              },
            ],
          },
        ],
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
      };

    case "food_recognition":
      return {
        contents: [
          {
            parts: [
              {
                text: `Sen bir beslenme uzmanısın. Bu fotoğraftaki yemeği analiz et.

Görevlerin:
1. Yemeğin ne olduğunu belirle (Türkçe isim)
2. Tahmini porsiyon büyüklüğü
3. Kalori ve makro besin değerlerini tahmin et (100g başına değil, fotoğraftaki porsiyon için)

Sadece şu JSON formatında döndür, başka bir şey yazma:
{"food_name":"","portion_grams":0,"energy_kcal":0,"fat":0,"saturated_fat":0,"sugars":0,"salt":0,"fiber":0,"protein":0,"confidence":0.0,"description":""}`,
              },
              {
                inline_data: {
                  mime_type: "image/jpeg",
                  data: payload.image_base64,
                },
              },
            ],
          },
        ],
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

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

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

    // Parse request
    const body: RequestBody = await req.json();
    const { action, payload } = body;

    if (!action || !payload) {
      return new Response(
        JSON.stringify({ error: "Missing action or payload" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
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
    const geminiBody = buildPrompt(action, payload);

    const geminiResponse = await fetch(
      `${GEMINI_URL}?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(geminiBody),
      }
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini API error:", errorText);
      return new Response(
        JSON.stringify({ error: "AI service error", details: errorText }),
        {
          status: 502,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const geminiData = await geminiResponse.json();
    const resultText =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    return new Response(
      JSON.stringify({ result: resultText, action }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
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
