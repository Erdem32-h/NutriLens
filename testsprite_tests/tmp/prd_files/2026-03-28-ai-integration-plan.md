# NutriLens AI Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Gemini 2.5 Flash AI integration for OCR improvement, ingredient verification, and barcodeless food recognition via Supabase Edge Function proxy.

**Architecture:** ML Kit (on-device) extracts raw OCR text, Gemini AI (via Supabase Edge Function) cleans/structures it. For barcodeless foods, camera photo is sent directly to Gemini for food identification and nutrition estimation. All AI calls go through `gemini-proxy` Edge Function for security and rate limiting.

**Tech Stack:** Flutter, Supabase Edge Functions (Deno/TypeScript), Google Gemini 2.5 Flash API, Google ML Kit, Riverpod

**Design Doc:** `docs/plans/2026-03-28-ai-integration-design.md`

---

## Phase 0: Bugfixes

### Task 0a: HP Score — expand critical ingredient keywords

The existing critical ingredient check (hp_score_calculator.dart:86-97) needs more keywords to catch English variants and common Turkish spelling variations.

**Files:**
- Modify: `lib/core/services/hp_score_calculator.dart:86-97`

**Step 1: Update critical ingredients list**

Replace lines 86-97 in `calculateFull()` with an expanded check:

```dart
// ── Critical ingredient blacklist ──
// If ANY of these are found → instant worst score (10.0 → gauge 5)
final String t = ingredientsText?.toLowerCase() ?? '';

const criticalPatterns = [
  // Palm oil (TR + EN)
  'palm yağ', 'palm oil', 'palmiye yağ',
  // Invert sugar
  'invert şeker', 'invert sugar',
  // Glucose syrup
  'glikoz şurubu', 'glikoz şurub', 'glucose syrup', 'glukoz şurubu',
  // Fructose syrup
  'fruktoz şurubu', 'fruktoz şurub', 'früktoz şurubu', 'früktoz şurub',
  'fructose syrup',
  // Corn syrup
  'mısır şurubu', 'mısır şurub', 'corn syrup',
  // High fructose corn syrup
  'yüksek fruktozlu', 'high fructose corn syrup', 'hfcs',
  // Generic sugar syrup
  'şeker şurubu', 'şeker şurub', 'sugar syrup',
];

final bool hasCriticalIngredients =
    criticalPatterns.any((pattern) => t.contains(pattern));

final double finalHpScore = hasCriticalIngredients ? 10.0 : hpScore;
final int finalGaugeLevel = hasCriticalIngredients
    ? 5
    : ScoreConstants.hpToGauge(finalHpScore);
```

**Step 2: Run flutter analyze**

Run: `flutter analyze --no-pub`
Expected: 0 errors, 0 warnings

**Step 3: Commit**

```bash
git add lib/core/services/hp_score_calculator.dart
git commit -m "fix: expand critical ingredient blacklist for instant worst score"
```

---

### Task 0b: Debug petit beurre photo upload

The photo upload silently fails for some products. Add diagnostic logging to identify root cause.

**Files:**
- Modify: `lib/features/product/presentation/screens/edit_product_screen.dart:1158-1183`

**Step 1: Add diagnostic logging to _uploadImage**

Replace the `_uploadImage` method:

```dart
Future<String?> _uploadImage(String userId) async {
  if (_selectedImage == null) return null;

  try {
    final fileSize = await _selectedImage!.length();
    debugPrint('[Upload] file: ${_selectedImage!.path}');
    debugPrint('[Upload] size: ${fileSize} bytes (${(fileSize / 1024).toStringAsFixed(1)} KB)');

    final ext = _selectedImage!.path.split('.').last;
    final safeExt = (ext.length > 5 || ext.contains(RegExp(r'[^a-zA-Z0-9]')))
        ? 'jpg'
        : ext;
    debugPrint('[Upload] extension: "$ext" → "$safeExt"');

    final sanitizedBarcode =
        widget.barcode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final path = 'products/${sanitizedBarcode}_$userId.$safeExt';
    debugPrint('[Upload] storage path: "$path"');
    debugPrint('[Upload] barcode: "${widget.barcode}" → sanitized: "$sanitizedBarcode"');

    // Check file exists and is readable
    if (!await _selectedImage!.exists()) {
      debugPrint('[Upload] ERROR: file does not exist at path!');
      return null;
    }

    await Supabase.instance.client.storage
        .from('product-images')
        .upload(path, _selectedImage!,
            fileOptions: const FileOptions(upsert: true));

    final publicUrl = Supabase.instance.client.storage
        .from('product-images')
        .getPublicUrl(path);

    debugPrint('[Upload] SUCCESS → $publicUrl');
    return publicUrl;
  } catch (e, stack) {
    debugPrint('[Upload] ERROR: $e');
    debugPrint('[Upload] stack: $stack');
    return null;
  }
}
```

**Step 2: Run flutter analyze**

Run: `flutter analyze --no-pub`
Expected: 0 errors, 0 warnings

**Step 3: Commit**

```bash
git add lib/features/product/presentation/screens/edit_product_screen.dart
git commit -m "fix: add diagnostic logging to photo upload for debugging"
```

**Step 4: Test with petit beurre barcode**

Run the app, scan petit beurre, take photo, save. Check debug console for `[Upload]` log lines. The logs will reveal whether the issue is:
- File path/extension problem
- File size too large
- Supabase storage error (permissions, bucket)
- Barcode sanitization issue

Fix based on findings.

---

## Phase 1: Supabase Edge Function — gemini-proxy

### Task 1a: Create gemini-proxy Edge Function

**Files:**
- Create: `supabase/functions/gemini-proxy/index.ts`

**Step 1: Create the Edge Function file**

```typescript
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

Görevlerin:
1. OCR hatalarını düzelt
2. Birimleri gram'a çevir (mg→g: /1000)
3. Değerleri 100g başına normalize et

OCR metni: ${payload.text}

Sadece şu JSON formatında döndür, başka bir şey yazma:
{"energy_kcal":0,"fat":0,"saturated_fat":0,"sugars":0,"salt":0,"fiber":0,"protein":0}`,
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
```

**Step 2: Set Gemini API key as Supabase secret**

Run: `supabase secrets set GEMINI_API_KEY=<your-gemini-api-key>`

**Step 3: Deploy Edge Function**

Run: `supabase functions deploy gemini-proxy`

**Step 4: Test Edge Function**

Use Supabase Dashboard or curl to test:
```bash
curl -X POST https://<project>.supabase.co/functions/v1/gemini-proxy \
  -H "Authorization: Bearer <user_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"action":"ocr_ingredients","payload":{"text":"Seker, un, palm yagi, tuz"}}'
```

Expected: `{"result":"Şeker, un, palm yağı, tuz","action":"ocr_ingredients"}`

**Step 5: Commit**

```bash
git add supabase/functions/gemini-proxy/
git commit -m "feat: add gemini-proxy Edge Function for AI integration"
```

---

## Phase 2: Flutter GeminiAiService + OCR Integration

### Task 2a: Create GeminiAiService

**Files:**
- Create: `lib/core/services/gemini_ai_service.dart`

**Step 1: Create the service**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/product/domain/entities/nutriments_entity.dart';

/// Result of AI food recognition from a photo.
class FoodRecognitionResult {
  final String foodName;
  final int portionGrams;
  final double energyKcal;
  final double fat;
  final double saturatedFat;
  final double sugars;
  final double salt;
  final double fiber;
  final double protein;
  final double confidence;
  final String description;

  const FoodRecognitionResult({
    required this.foodName,
    required this.portionGrams,
    required this.energyKcal,
    required this.fat,
    required this.saturatedFat,
    required this.sugars,
    required this.salt,
    required this.fiber,
    required this.protein,
    required this.confidence,
    required this.description,
  });

  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) {
    return FoodRecognitionResult(
      foodName: json['food_name'] as String? ?? 'Bilinmeyen Yemek',
      portionGrams: (json['portion_grams'] as num?)?.toInt() ?? 0,
      energyKcal: (json['energy_kcal'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      saturatedFat: (json['saturated_fat'] as num?)?.toDouble() ?? 0,
      sugars: (json['sugars'] as num?)?.toDouble() ?? 0,
      salt: (json['salt'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
    );
  }

  /// Convert to NutrimentsEntity for HP Score calculation.
  NutrimentsEntity toNutriments() {
    return NutrimentsEntity(
      energyKcal: energyKcal,
      fat: fat,
      saturatedFat: saturatedFat,
      sugars: sugars,
      salt: salt,
      fiber: fiber,
      proteins: protein,
    );
  }
}

/// Result of AI-improved nutrition OCR.
class NutritionOcrResult {
  final double? energyKcal;
  final double? fat;
  final double? saturatedFat;
  final double? sugars;
  final double? salt;
  final double? fiber;
  final double? protein;

  const NutritionOcrResult({
    this.energyKcal,
    this.fat,
    this.saturatedFat,
    this.sugars,
    this.salt,
    this.fiber,
    this.protein,
  });

  factory NutritionOcrResult.fromJson(Map<String, dynamic> json) {
    return NutritionOcrResult(
      energyKcal: (json['energy_kcal'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      saturatedFat: (json['saturated_fat'] as num?)?.toDouble(),
      sugars: (json['sugars'] as num?)?.toDouble(),
      salt: (json['salt'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
    );
  }
}

/// Service for AI-powered food analysis via Supabase Edge Function.
class GeminiAiService {
  final SupabaseClient _client;

  const GeminiAiService(this._client);

  /// Improve OCR-extracted ingredients text using Gemini AI.
  /// Returns cleaned text, or null on failure (caller should fallback).
  Future<String?> improveIngredientsOcr(String rawText) async {
    try {
      final response = await _invoke('ocr_ingredients', {'text': rawText});
      final result = response['result'] as String?;
      if (result == null || result.trim().isEmpty) return null;
      return result.trim();
    } catch (e) {
      debugPrint('[GeminiAI] improveIngredientsOcr error: $e');
      return null;
    }
  }

  /// Improve OCR-extracted nutrition table using Gemini AI.
  /// Returns structured nutrition data, or null on failure.
  Future<NutritionOcrResult?> improveNutritionOcr(String rawText) async {
    try {
      final response = await _invoke('ocr_nutrition', {'text': rawText});
      final result = response['result'] as String?;
      if (result == null || result.trim().isEmpty) return null;

      // Parse JSON from Gemini response (may have markdown fences)
      final jsonStr = _extractJson(result);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NutritionOcrResult.fromJson(json);
    } catch (e) {
      debugPrint('[GeminiAI] improveNutritionOcr error: $e');
      return null;
    }
  }

  /// Recognize food from photo and estimate nutrition.
  /// Throws on failure (caller should show error to user).
  Future<FoodRecognitionResult> recognizeFood(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final response = await _invoke(
      'food_recognition',
      {'image_base64': base64Image},
    );

    final result = response['result'] as String?;
    if (result == null || result.trim().isEmpty) {
      throw Exception('AI returned empty result');
    }

    final jsonStr = _extractJson(result);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FoodRecognitionResult.fromJson(json);
  }

  /// Invoke the gemini-proxy Edge Function.
  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'gemini-proxy',
      body: {'action': action, 'payload': payload},
    );

    if (response.status != 200) {
      final errorMsg = response.data?['error'] ?? 'Unknown error';
      throw Exception('Edge Function error ($action): $errorMsg');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Extract JSON from a response that may contain markdown fences.
  String _extractJson(String text) {
    // Remove ```json ... ``` fences if present
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = fencePattern.firstMatch(text);
    if (match != null) return match.group(1)!.trim();

    // Try to find JSON object directly
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final jsonMatch = jsonPattern.firstMatch(text);
    if (jsonMatch != null) return jsonMatch.group(0)!;

    return text.trim();
  }
}
```

**Step 2: Add Riverpod provider**

Modify: `lib/features/product/presentation/providers/product_provider.dart`

Add at the bottom of the file:

```dart
import '../../../../core/services/gemini_ai_service.dart';

final geminiAiServiceProvider = Provider<GeminiAiService>((ref) {
  return GeminiAiService(Supabase.instance.client);
});
```

**Step 3: Run flutter analyze**

Run: `flutter analyze --no-pub`
Expected: 0 errors, 0 warnings

**Step 4: Commit**

```bash
git add lib/core/services/gemini_ai_service.dart lib/features/product/presentation/providers/product_provider.dart
git commit -m "feat: add GeminiAiService for AI-powered food analysis"
```

---

### Task 2b: Integrate AI into OCR flow (edit_product_screen.dart)

**Files:**
- Modify: `lib/features/product/presentation/screens/edit_product_screen.dart`

**Step 1: Update _scanWithOcr to use GeminiAiService**

In the `_scanWithOcr` method, after ML Kit extraction and OcrTextProcessor, add AI improvement:

For `_OcrTarget.ingredients`:
```dart
case _OcrTarget.ingredients:
  final mlKitResult = processor.processIngredients(recognizedText);
  if (mlKitResult.text.isEmpty) {
    _showMessage(l10n.ocrNoText);
    return;
  }

  // Try AI improvement (silent — fallback to ML Kit result on failure)
  final aiService = ref.read(geminiAiServiceProvider);
  final aiImproved = await aiService.improveIngredientsOcr(mlKitResult.text);

  setState(() {
    _ingredientsController.text = aiImproved ?? mlKitResult.text;
  });
  debugPrint('[OCR] ingredients ai=${aiImproved != null}, '
      'lang=${mlKitResult.language}');
  _showMessage(l10n.ocrSuccess);
```

For `_OcrTarget.nutrition`:
```dart
case _OcrTarget.nutrition:
  final mlKitResult = processor.processNutrition(recognizedText);
  if (mlKitResult.text.isEmpty) {
    _showMessage(l10n.ocrNoText);
    return;
  }

  // Try AI improvement for structured data
  final aiService = ref.read(geminiAiServiceProvider);
  final aiResult = await aiService.improveNutritionOcr(mlKitResult.text);

  if (aiResult != null) {
    // AI returned structured data — fill fields directly
    setState(() {
      if (aiResult.energyKcal != null && _energyController.text.isEmpty) {
        _energyController.text = aiResult.energyKcal!.toStringAsFixed(1);
      }
      if (aiResult.fat != null && _fatController.text.isEmpty) {
        _fatController.text = aiResult.fat!.toStringAsFixed(1);
      }
      if (aiResult.saturatedFat != null && _saturatedFatController.text.isEmpty) {
        _saturatedFatController.text = aiResult.saturatedFat!.toStringAsFixed(1);
      }
      if (aiResult.sugars != null && _sugarsController.text.isEmpty) {
        _sugarsController.text = aiResult.sugars!.toStringAsFixed(1);
      }
      if (aiResult.salt != null && _saltController.text.isEmpty) {
        _saltController.text = aiResult.salt!.toStringAsFixed(3);
      }
      if (aiResult.fiber != null && _fiberController.text.isEmpty) {
        _fiberController.text = aiResult.fiber!.toStringAsFixed(1);
      }
      if (aiResult.protein != null && _proteinController.text.isEmpty) {
        _proteinController.text = aiResult.protein!.toStringAsFixed(1);
      }
    });
  } else {
    // AI failed — fallback to regex-based parsing
    _parseNutritionFromOcr(mlKitResult.text);
  }
  debugPrint('[OCR] nutrition ai=${aiResult != null}');
  _showMessage(l10n.ocrSuccess);
```

**Step 2: Run flutter analyze**

Run: `flutter analyze --no-pub`

**Step 3: Commit**

```bash
git add lib/features/product/presentation/screens/edit_product_screen.dart
git commit -m "feat: integrate AI OCR improvement into ingredient/nutrition scanning"
```

---

## Phase 3: Scanner Dual Mode + Food Recognition

### Task 3a: Add l10n strings for AI features

**Files:**
- Modify: `lib/l10n/app_tr.arb`
- Modify: `lib/l10n/app_en.arb`

**Step 1: Add Turkish strings**

Add to `app_tr.arb`:
```json
"tabBarcode": "Barkod",
"tabAiAnalysis": "AI Analiz",
"aiAnalysisHint": "Yemeği çerçeve içine alın",
"aiAnalyzing": "AI analiz ediyor...",
"aiAnalysisResult": "AI Analiz Sonucu",
"aiEstimatedPortion": "Tahmini porsiyon",
"aiConfidence": "Güven",
"aiSaveToHistory": "Geçmişe Kaydet",
"aiRetake": "Tekrar Çek",
"aiSaved": "AI analiz sonucu kaydedildi",
"aiFailed": "AI analiz başarısız oldu. Tekrar deneyin.",
"aiLowConfidence": "Düşük güven — sonuçlar tahminidir",
"aiEstimate": "AI Tahmin",
"carbohydrates": "Karbonhidrat"
```

**Step 2: Add English strings**

Add to `app_en.arb`:
```json
"tabBarcode": "Barcode",
"tabAiAnalysis": "AI Analysis",
"aiAnalysisHint": "Frame the food in the viewfinder",
"aiAnalyzing": "AI is analyzing...",
"aiAnalysisResult": "AI Analysis Result",
"aiEstimatedPortion": "Estimated portion",
"aiConfidence": "Confidence",
"aiSaveToHistory": "Save to History",
"aiRetake": "Retake Photo",
"aiSaved": "AI analysis result saved",
"aiFailed": "AI analysis failed. Please try again.",
"aiLowConfidence": "Low confidence — results are estimates",
"aiEstimate": "AI Estimate",
"carbohydrates": "Carbohydrates"
```

**Step 3: Commit**

```bash
git add lib/l10n/app_tr.arb lib/l10n/app_en.arb
git commit -m "feat: add l10n strings for AI analysis feature"
```

---

### Task 3b: Refactor scanner screen to dual mode

**Files:**
- Modify: `lib/features/scanner/presentation/screens/scanner_screen.dart`

**Step 1: Add tab state and AI capture mode**

Add to `_ScannerScreenState`:
- `int _scanMode = 0;` (0 = barcode, 1 = AI)
- Tab bar widget at top of scanner
- When AI mode selected: hide barcode scanning overlay, show capture button
- On capture: pick image → navigate to food result screen

The scanner screen should:
1. Add a pill-shaped tab selector below the top bar: "🔲 Barkod" | "📷 AI Analiz"
2. In barcode mode (0): existing MobileScanner + overlay (no changes)
3. In AI mode (1): same camera preview but with a large capture button at bottom center and "Yemeği çerçeve içine alın" hint text

**Step 2: Add capture and navigation logic for AI mode**

When capture button is tapped:
1. Call `_controller.stop()` to pause scanning
2. Use `ImagePicker` to take photo from camera
3. Navigate to `/food-result` with image bytes as extra
4. On return, call `_controller.start()`

**Step 3: Run flutter analyze**

**Step 4: Commit**

```bash
git add lib/features/scanner/presentation/screens/scanner_screen.dart
git commit -m "feat: add dual mode (barcode/AI) to scanner screen"
```

---

### Task 3c: Create FoodResultScreen

**Files:**
- Create: `lib/features/scanner/presentation/screens/food_result_screen.dart`

**Step 1: Create the screen**

The screen receives `Uint8List imageBytes` via route extra. It:
1. Shows the captured photo at the top
2. Calls `geminiAiServiceProvider` to recognize the food
3. Shows loading state ("AI analiz ediyor...")
4. On success: displays food name, portion, confidence, HP gauge, macro grid
5. On error: shows error with retry button
6. "Geçmişe Kaydet" button: creates ProductEntity with virtual barcode (`ai_{timestamp}_{shortUuid}`), saves to community_products and scan_history
7. "Tekrar Çek" button: pops back to scanner

**Key layout:**
- Photo thumbnail (16:9 aspect, rounded)
- Food name (large, bold)
- Portion + confidence badges
- HealthScoreBar widget (reuse existing)
- 2x3 macro grid (kcal, protein, fat, carb, fiber, salt)
- Low confidence warning if < 0.6
- Two action buttons at bottom

**Step 2: Add route**

In `app_router.dart`, add:
```dart
GoRoute(
  path: '/food-result',
  name: RouteNames.foodResult,
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) {
    final imageBytes = state.extra as Uint8List;
    return FoodResultScreen(imageBytes: imageBytes);
  },
),
```

In `route_names.dart`, add:
```dart
static const String foodResult = 'foodResult';
```

**Step 3: Run flutter analyze**

**Step 4: Commit**

```bash
git add lib/features/scanner/presentation/screens/food_result_screen.dart \
        lib/config/router/app_router.dart \
        lib/config/router/route_names.dart
git commit -m "feat: add FoodResultScreen for AI food recognition results"
```

---

## Phase 4: History Integration for AI Foods

### Task 4a: Display AI foods in history/favorites

**Files:**
- Modify: `lib/features/history/presentation/screens/history_screen.dart`
- Modify: `lib/features/favorites/presentation/screens/favorites_screen.dart`

**Step 1: Add AI indicator to history tiles**

In `_HistoryTile`, check if `item.barcode` starts with `ai_`. If so:
- Show 🤖 icon instead of product image placeholder
- Show "AI Tahmin" as subtitle instead of brand name

Same logic for `_FavoriteTile`.

**Step 2: Run flutter analyze**

**Step 3: Commit**

```bash
git add lib/features/history/presentation/screens/history_screen.dart \
        lib/features/favorites/presentation/screens/favorites_screen.dart
git commit -m "feat: display AI-recognized foods with indicator in history/favorites"
```

---

### Task 4b: Final integration test

**Step 1: Test OCR improvement flow**
- Scan a barcoded product with missing data
- Take photo of ingredients label → verify AI improves the text
- Take photo of nutrition table → verify AI fills fields correctly
- Save → verify HP score is calculated

**Step 2: Test food recognition flow**
- Go to scanner → switch to "AI Analiz" tab
- Take photo of a meal
- Verify food name, calories, macros appear
- Tap "Geçmişe Kaydet" → verify appears in history with 🤖 icon
- Tap the history entry → verify product detail page works

**Step 3: Test edge cases**
- No internet → verify graceful fallback (OCR uses ML Kit result)
- Rate limit → verify error message
- Low confidence food → verify warning label

**Step 4: Final commit**

```bash
git commit -m "feat: NutriLens AI integration complete"
```
