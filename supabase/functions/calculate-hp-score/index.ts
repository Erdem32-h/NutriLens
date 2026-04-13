import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── HP Score constants (mirrors Dart ScoreConstants) ─────────────────────────
const CHEMICAL_WEIGHT = 0.45
const RISK_WEIGHT = 0.40
const NUTRI_WEIGHT = 0.15

const ADDITIVE_PENALTIES: Record<number, number> = {
  1: 0.0,
  2: 4.0,
  3: 10.0,
  4: 18.0,
  5: 28.0,
}

const SUGAR_MAX_REF = 22.5
const SALT_MAX_REF = 2.4
const SAT_FAT_MAX_REF = 10.0
const SUGAR_WEIGHT = 0.40
const SALT_WEIGHT = 0.25
const SAT_FAT_WEIGHT = 0.35

const FIBER_EXCELLENT = 6.0
const PROTEIN_EXCELLENT = 15.0
const FIBER_WEIGHT = 0.30
const PROTEIN_WEIGHT = 0.30
const NATURALNESS_WEIGHT = 0.40

const NOVA_NATURALNESS: Record<number, number> = { 1: 100, 2: 60, 3: 30, 4: 0 }
const NOVA_UNKNOWN = 15.0

const GAUGE_THRESHOLDS = [75, 55, 35, 18]

const CRITICAL_PATTERNS = [
  'palm yag', 'palm oil', 'palmiye yag',
  'invert seker', 'invert sugar',
  'glikoz surubu', 'glucose syrup', 'glukoz surubu',
  'fruktoz surubu', 'fructose syrup',
  'misir surubu', 'corn syrup',
  'yuksek fruktozlu', 'high fructose corn syrup', 'hfcs',
]

// ── Helpers ───────────────────────────────────────────────────────────────────

function normalizeTurkish(text: string): string {
  return text.toLowerCase()
    .replace(/i̇/g, 'i').replace(/ı/g, 'i')
    .replace(/ş/g, 's').replace(/ğ/g, 'g')
    .replace(/ü/g, 'u').replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
}

function normalizeECode(tag: string): string {
  let code = tag.trim().toLowerCase()
  if (code.startsWith('en:')) code = code.slice(3)
  code = code.replace(/[\s\-]/g, '')
  const match = code.match(/^e(\d{3,4}[a-z]?)$/)
  if (!match) return tag
  return `E${match[1]}`
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

function hpToGauge(hp: number): number {
  if (hp >= GAUGE_THRESHOLDS[0]) return 1
  if (hp >= GAUGE_THRESHOLDS[1]) return 2
  if (hp >= GAUGE_THRESHOLDS[2]) return 3
  if (hp >= GAUGE_THRESHOLDS[3]) return 4
  return 5
}

// ── Interfaces ────────────────────────────────────────────────────────────────

interface Nutriments {
  energy_kcal?: number
  fat?: number
  saturated_fat?: number
  sugars?: number
  salt?: number
  fiber?: number
  proteins?: number
}

interface HpScoreRequest {
  barcode: string
  additives_tags: string[]
  nutriments: Nutriments
  nova_group?: number
  ingredients_text?: string
}

interface HpScoreResponse {
  hp_score: number
  chemical_load: number
  risk_factor: number
  nutri_factor: number
  gauge_level: number
  is_partial: boolean
}

// ── Core calculation ──────────────────────────────────────────────────────────

async function getAdditiveRiskLevels(
  supabase: ReturnType<typeof createClient>,
  eCodes: string[]
): Promise<Map<string, number>> {
  if (eCodes.length === 0) return new Map()

  const { data } = await supabase
    .from('additives')
    .select('e_number, risk_level')
    .in('e_number', eCodes)

  const map = new Map<string, number>()
  if (data) {
    for (const row of data) {
      map.set(row.e_number, row.risk_level)
    }
  }
  return map
}

function extractECodesFromText(text: string): string[] {
  const matches = text.matchAll(/\bE[\s\-]?(\d{3,4}[a-z]?)\b/gi)
  const codes = new Set<string>()
  for (const m of matches) {
    codes.add(`E${m[1]}`)
  }
  return [...codes]
}

async function calculateChemicalLoad(
  supabase: ReturnType<typeof createClient>,
  additiveTags: string[],
  ingredientsText?: string
): Promise<number> {
  const allCodes = new Set<string>()
  for (const tag of additiveTags) allCodes.add(normalizeECode(tag))
  if (ingredientsText) {
    for (const code of extractECodesFromText(ingredientsText)) allCodes.add(code)
  }

  if (allCodes.size === 0) return 0

  const riskMap = await getAdditiveRiskLevels(supabase, [...allCodes])

  let total = 0
  for (const code of allCodes) {
    const risk = riskMap.get(code) ?? 3 // default moderate
    total += ADDITIVE_PENALTIES[risk] ?? 10
  }
  return Math.min(total, 100)
}

function calculateRiskFactor(n: Nutriments): number {
  const sugar = clamp((n.sugars ?? 0) / SUGAR_MAX_REF, 0, 1) * 100
  const salt = clamp((n.salt ?? 0) / SALT_MAX_REF, 0, 1) * 100
  const satFat = clamp((n.saturated_fat ?? 0) / SAT_FAT_MAX_REF, 0, 1) * 100
  return sugar * SUGAR_WEIGHT + salt * SALT_WEIGHT + satFat * SAT_FAT_WEIGHT
}

function calculateNutriFactor(n: Nutriments, novaGroup?: number): number {
  const fiber = clamp((n.fiber ?? 0) / FIBER_EXCELLENT, 0, 1) * 100
  const protein = clamp((n.proteins ?? 0) / PROTEIN_EXCELLENT, 0, 1) * 100
  const naturalness = novaGroup != null
    ? (NOVA_NATURALNESS[novaGroup] ?? NOVA_UNKNOWN)
    : NOVA_UNKNOWN
  return fiber * FIBER_WEIGHT + protein * PROTEIN_WEIGHT + naturalness * NATURALNESS_WEIGHT
}

// ── Handler ───────────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body: HpScoreRequest = await req.json()

    const chemicalLoad = await calculateChemicalLoad(
      supabase,
      body.additives_tags ?? [],
      body.ingredients_text
    )
    const riskFactor = calculateRiskFactor(body.nutriments ?? {})
    const nutriFactor = calculateNutriFactor(body.nutriments ?? {}, body.nova_group)

    let hpScore = clamp(
      100 - chemicalLoad * CHEMICAL_WEIGHT - riskFactor * RISK_WEIGHT + nutriFactor * NUTRI_WEIGHT,
      0,
      100
    )

    // Critical ingredient check → instant score 10
    const normalizedText = body.ingredients_text
      ? normalizeTurkish(body.ingredients_text)
      : ''
    const hasCritical = CRITICAL_PATTERNS.some((p) => normalizedText.includes(p))
    if (hasCritical) hpScore = 10

    const response: HpScoreResponse = {
      hp_score: Math.round(hpScore * 10) / 10,
      chemical_load: Math.round(chemicalLoad * 10) / 10,
      risk_factor: Math.round(riskFactor * 10) / 10,
      nutri_factor: Math.round(nutriFactor * 10) / 10,
      gauge_level: hpToGauge(hpScore),
      is_partial: false,
    }

    // Cache in food_products table
    if (body.barcode) {
      await supabase
        .from('food_products')
        .update({ hp_score: hpScore })
        .eq('barcode', body.barcode)
    }

    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
})
