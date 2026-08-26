-- HP Score v4: derives a NOVA group from the ingredient list when the source
-- did not supply one, and caps ultra-processed (NOVA 4) products at the top of
-- gauge 3 so they can never read as "İyi" or "Çok İyi".
--
-- Why both halves ship together:
--   * NOVA reached the score only through `naturalness`, worth 0.15 × 0.40.
--     The whole NOVA range moves a score by 6 points and unknown→4 by 0.9 —
--     invisible next to gauge bands 55 and 35. Filling the field alone changed
--     the gauge of exactly 1 product in 71.
--   * A ceiling without derivation would be arbitrary: 48 of 71 rows have no
--     nova_group, so whether a product got capped would depend on whether Open
--     Food Facts happened to fill the field, not on the product.
--
-- Measured against the 23 rows that do carry a source NOVA group, the
-- derivation flags 15 of 15 group-4 rows and none of the 8 group-1/3 rows.
-- Net effect on the table: 4 gauge changes out of 71 — a tomato sauce with
-- sweetener (1→3), sugar-free gum with six sweeteners (2→3), a sherbet (2→3)
-- and a cordial (2→3).
--
-- Mirrors lib/core/services/nova_derivation.dart,
-- lib/core/services/hp_score_calculator.dart and
-- lib/core/constants/score_constants.dart (hpScoreAlgorithmVersion = 4).

create or replace function public.recalculate_community_product_hp_score()
returns trigger
language plpgsql
as $$
declare
  normalized_text text;
  derivation_text text;
  sugars numeric;
  salt_value numeric;
  saturated_fat numeric;
  fiber numeric;
  proteins numeric;
  chemical_load numeric;
  risk_factor numeric;
  nutri_factor numeric;
  ingredient_quality_penalty numeric;
  has_added_sugar boolean;
  has_refined_flour boolean;
  has_sweet_treat boolean;
  has_critical boolean;
  is_ultra_processed boolean;
  effective_nova integer;
  raw_score numeric;
begin
  normalized_text := translate(
    lower(coalesce(new.ingredients_text, '')),
    'ıİğĞüÜşŞöÖçÇ',
    'iigguussoocc'
  );

  -- Derivation also reads the additive tags, because a product may carry
  -- "en:e171" as structured data while its ingredient text says nothing.
  derivation_text := translate(
    lower(coalesce(new.ingredients_text, '') || ' ' || coalesce(new.additives_tags::text, '')),
    'ıİğĞüÜşŞöÖçÇ',
    'iigguussoocc'
  );

  sugars := coalesce(nullif(regexp_replace(new.nutriments->>'sugars', '[^0-9.-]', '', 'g'), '')::numeric, 0);
  salt_value := coalesce(nullif(regexp_replace(new.nutriments->>'salt', '[^0-9.-]', '', 'g'), '')::numeric, 0);
  saturated_fat := coalesce(nullif(regexp_replace(new.nutriments->>'saturated_fat', '[^0-9.-]', '', 'g'), '')::numeric, 0);
  fiber := coalesce(nullif(regexp_replace(new.nutriments->>'fiber', '[^0-9.-]', '', 'g'), '')::numeric, 0);
  proteins := coalesce(nullif(regexp_replace(new.nutriments->>'proteins', '[^0-9.-]', '', 'g'), '')::numeric, 0);

  select least(
    coalesce(
      sum(
        case coalesce(a.risk_level, 3)
          when 1 then 0
          when 2 then 4
          when 3 then 10
          when 4 then 18
          when 5 then 28
          else 10
        end
      ),
      0
    ),
    100
  )
  into chemical_load
  from (
    select upper(regexp_replace(regexp_replace(tag.value, '^en:', '', 'i'), '[\s-]', '', 'g')) as e_number
    from jsonb_array_elements_text(coalesce(new.additives_tags, '[]'::jsonb)) as tag(value)

    union

    select 'E' || upper(match[1]) as e_number
    from regexp_matches(
      coalesce(new.ingredients_text, ''),
      '\mE[\s-]?([0-9]{3,4}[a-z]?)\M',
      'gi'
    ) as match
  ) codes
  left join public.additives a on a.e_number = codes.e_number;

  -- v4 addition: NOVA group 4 read off the label. Cosmetic additive classes
  -- (colours E1xx, emulsifiers/thickeners E4xx, flavour enhancers E62x-E65x,
  -- sweeteners E95x-E96x) plus substances no domestic kitchen holds. E2xx
  -- preservatives, E3xx antioxidants and E5xx are deliberately absent —
  -- salting, vitamin C and baking soda are not marks of ultra-processing.
  -- E322 is the one number pulled out of the excluded E3xx block: lecithin is
  -- an emulsifier filed with the antioxidants.
  --
  -- Only group 4 is derived. One positive marker proves ultra-processing;
  -- proving a whole food needs every marker to be absent, and a half-OCR'd
  -- label looks exactly like a clean one.
  is_ultra_processed :=
    derivation_text ~ '\me[\s-]?(1[0-9]{2}|322|4[0-9]{2}|6[2-5][0-9]|9[5-6][0-9])[a-z]?\M'
    or derivation_text ~ 'hidrojenize|hydrogenated|maltodekstrin|maltodextrin|glikoz-fruktoz|fruktoz-glukoz|fruktoz-glikoz|glucose-fructose|high fructose|invert (seker|sugar)|modifiye nisasta|modified (potato |corn |food )?starch|protein izolat|protein isolate|tatlandirici|sweetener|emulgator|emulsifier|renklendirici|farbstoff|colou?ring|artificial (flavor|colour|color)|natural flavor|aroma verici|aromen|kivam artirici|thickener';

  -- A source-supplied group always wins; derivation only fills the gap.
  effective_nova := coalesce(
    new.nova_group,
    case when is_ultra_processed then 4 else null end
  );

  risk_factor :=
    least(sugars / 22.5, 1) * 100 * 0.40 +
    least(salt_value / 2.4, 1) * 100 * 0.25 +
    least(saturated_fat / 10.0, 1) * 100 * 0.35;

  nutri_factor :=
    least(fiber / 6.0, 1) * 100 * 0.30 +
    least(proteins / 15.0, 1) * 100 * 0.30 +
    (
      case effective_nova
        when 1 then 100
        when 2 then 60
        when 3 then 30
        when 4 then 0
        else 15
      end
    ) * 0.40;

  has_added_sugar :=
    normalized_text like '%seker%' or
    normalized_text like '%sugar%' or
    normalized_text like '%sakkaroz%' or
    normalized_text like '%sucrose%' or
    normalized_text like '%dekstroz%' or
    normalized_text like '%dextrose%' or
    normalized_text like '%glikoz%' or
    normalized_text like '%glucose%';

  has_refined_flour :=
    normalized_text like '%bugday unu%' or
    normalized_text like '%beyaz un%' or
    normalized_text like '%wheat flour%' or
    normalized_text like '%white flour%' or
    normalized_text like '%flour%' or
    normalized_text ~ '(^|[^a-z])un([^a-z]|$)';

  -- v3 addition: sweet/fatty treat. Gated on hasAddedSugar so plain
  -- high-fat foods (olive oil, butter, nut butter) are untouched.
  has_sweet_treat :=
    has_added_sugar and (sugars >= 25.0 or saturated_fat >= 8.0);

  ingredient_quality_penalty :=
    least(
      case when has_added_sugar then 18 else 0 end +
      case when has_refined_flour then 12 else 0 end +
      case when has_added_sugar and has_refined_flour then 10 else 0 end +
      case when has_sweet_treat then 15 else 0 end,
      40
    );

  has_critical :=
    normalized_text like '%palm yag%' or
    normalized_text like '%palm oil%' or
    normalized_text like '%palmiye yag%' or
    normalized_text like '%invert seker%' or
    normalized_text like '%invert sugar%' or
    normalized_text like '%glikoz surubu%' or
    normalized_text like '%glikoz surub%' or
    normalized_text like '%glucose syrup%' or
    normalized_text like '%glukoz surubu%' or
    normalized_text like '%fruktoz surubu%' or
    normalized_text like '%fruktoz surub%' or
    normalized_text like '%fructose syrup%' or
    normalized_text like '%misir surubu%' or
    normalized_text like '%misir surub%' or
    normalized_text like '%corn syrup%' or
    normalized_text like '%yuksek fruktozlu%' or
    normalized_text like '%high fructose corn syrup%' or
    normalized_text like '%hfcs%' or
    normalized_text like '%seker surubu%' or
    normalized_text like '%seker surub%' or
    normalized_text like '%sugar syrup%';

  raw_score := greatest(
    least(
      100 - chemical_load * 0.45 - risk_factor * 0.40 + nutri_factor * 0.15 - ingredient_quality_penalty,
      100
    ),
    0
  );

  new.hp_chemical_load := round(chemical_load, 2);
  new.hp_risk_factor := round(risk_factor, 2);
  new.hp_nutri_factor := round(nutri_factor, 2);
  new.hp_score_version := 4;
  new.hp_score := case
    when has_critical then 10.0
    -- v4 addition: the ultra-processed ceiling. Nutrition alone cannot lift an
    -- ultra-processed product into "İyi" — sugar-free gum reads as harmless on
    -- the panel and used to reach gauge 2 on the strength of what it lacks.
    when effective_nova = 4 then round(least(raw_score, 54.9), 2)
    else round(raw_score, 2)
  end;
  new.updated_at := now();

  return new;
end;
$$;

-- Trigger definition is already in place from the v2 migration; we
-- only rewrote the function body. No need to re-create the trigger.

-- One-shot back-fill so existing rows pick up v4 immediately.
-- NOTE: the trigger is BEFORE UPDATE OF (ingredients_text, additives_tags,
-- nutriments, nova_group), so we must touch one of those columns. A
-- `set updated_at = now()` would NOT fire the trigger and silently no-op.
update public.community_products set ingredients_text = ingredients_text;
