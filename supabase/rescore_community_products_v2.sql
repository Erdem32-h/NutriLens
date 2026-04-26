with product_codes as (
  select
    cp.id,
    upper(regexp_replace(regexp_replace(tag.value, '^en:', '', 'i'), '[\s-]', '', 'g')) as e_number
  from public.community_products cp
  cross join lateral jsonb_array_elements_text(coalesce(cp.additives_tags, '[]'::jsonb)) as tag(value)

  union

  select
    cp.id,
    'E' || upper(match[1]) as e_number
  from public.community_products cp
  cross join lateral regexp_matches(
    coalesce(cp.ingredients_text, ''),
    '\mE[\s-]?([0-9]{3,4}[a-z]?)\M',
    'gi'
  ) as match
),
chemical_loads as (
  select
    pc.id,
    least(
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
    )::numeric as chemical_load
  from product_codes pc
  left join public.additives a on a.e_number = pc.e_number
  group by pc.id
),
normalized as (
  select
    cp.*,
    translate(
      lower(coalesce(cp.ingredients_text, '')),
      'ıİğĞüÜşŞöÖçÇ',
      'iigguussoocc'
    ) as normalized_text,
    coalesce(nullif(regexp_replace(cp.nutriments->>'sugars', '[^0-9.-]', '', 'g'), '')::numeric, 0) as sugars,
    coalesce(nullif(regexp_replace(cp.nutriments->>'salt', '[^0-9.-]', '', 'g'), '')::numeric, 0) as salt,
    coalesce(nullif(regexp_replace(cp.nutriments->>'saturated_fat', '[^0-9.-]', '', 'g'), '')::numeric, 0) as saturated_fat,
    coalesce(nullif(regexp_replace(cp.nutriments->>'fiber', '[^0-9.-]', '', 'g'), '')::numeric, 0) as fiber,
    coalesce(nullif(regexp_replace(cp.nutriments->>'proteins', '[^0-9.-]', '', 'g'), '')::numeric, 0) as proteins
  from public.community_products cp
),
metrics as (
  select
    n.id,
    coalesce(cl.chemical_load, 0) as chemical_load,
    (
      least(n.sugars / 22.5, 1) * 100 * 0.40 +
      least(n.salt / 2.4, 1) * 100 * 0.25 +
      least(n.saturated_fat / 10.0, 1) * 100 * 0.35
    ) as risk_factor,
    (
      least(n.fiber / 6.0, 1) * 100 * 0.30 +
      least(n.proteins / 15.0, 1) * 100 * 0.30 +
      (
        case n.nova_group
          when 1 then 100
          when 2 then 60
          when 3 then 30
          when 4 then 0
          else 15
        end
      ) * 0.40
    ) as nutri_factor,
    least(
      (
        case
          when n.normalized_text like '%seker%'
            or n.normalized_text like '%sugar%'
            or n.normalized_text like '%sakkaroz%'
            or n.normalized_text like '%sucrose%'
            or n.normalized_text like '%dekstroz%'
            or n.normalized_text like '%dextrose%'
            or n.normalized_text like '%glikoz%'
            or n.normalized_text like '%glucose%'
          then 18
          else 0
        end
      ) +
      (
        case
          when n.normalized_text like '%bugday unu%'
            or n.normalized_text like '%beyaz un%'
            or n.normalized_text like '%wheat flour%'
            or n.normalized_text like '%white flour%'
            or n.normalized_text like '%flour%'
            or n.normalized_text ~ '(^|[^a-z])un([^a-z]|$)'
          then 12
          else 0
        end
      ) +
      (
        case
          when (
            n.normalized_text like '%seker%'
            or n.normalized_text like '%sugar%'
            or n.normalized_text like '%sakkaroz%'
            or n.normalized_text like '%sucrose%'
            or n.normalized_text like '%dekstroz%'
            or n.normalized_text like '%dextrose%'
            or n.normalized_text like '%glikoz%'
            or n.normalized_text like '%glucose%'
          )
          and (
            n.normalized_text like '%bugday unu%'
            or n.normalized_text like '%beyaz un%'
            or n.normalized_text like '%wheat flour%'
            or n.normalized_text like '%white flour%'
            or n.normalized_text like '%flour%'
            or n.normalized_text ~ '(^|[^a-z])un([^a-z]|$)'
          )
          then 10
          else 0
        end
      ),
      35
    ) as ingredient_quality_penalty,
    (
      n.normalized_text like '%palm yag%'
      or n.normalized_text like '%palm oil%'
      or n.normalized_text like '%palmiye yag%'
      or n.normalized_text like '%invert seker%'
      or n.normalized_text like '%invert sugar%'
      or n.normalized_text like '%glikoz surubu%'
      or n.normalized_text like '%glikoz surub%'
      or n.normalized_text like '%glucose syrup%'
      or n.normalized_text like '%glukoz surubu%'
      or n.normalized_text like '%fruktoz surubu%'
      or n.normalized_text like '%fruktoz surub%'
      or n.normalized_text like '%fructose syrup%'
      or n.normalized_text like '%misir surubu%'
      or n.normalized_text like '%misir surub%'
      or n.normalized_text like '%corn syrup%'
      or n.normalized_text like '%yuksek fruktozlu%'
      or n.normalized_text like '%high fructose corn syrup%'
      or n.normalized_text like '%hfcs%'
      or n.normalized_text like '%seker surubu%'
      or n.normalized_text like '%seker surub%'
      or n.normalized_text like '%sugar syrup%'
    ) as has_critical
  from normalized n
  left join chemical_loads cl on cl.id = n.id
),
scored as (
  select
    id,
    round(chemical_load, 2) as chemical_load,
    round(risk_factor, 2) as risk_factor,
    round(nutri_factor, 2) as nutri_factor,
    case
      when has_critical then 10.0
      else round(
        greatest(
          least(
            100 - chemical_load * 0.45 - risk_factor * 0.40 + nutri_factor * 0.15 - ingredient_quality_penalty,
            100
          ),
          0
        ),
        2
      )
    end as hp_score
  from metrics
)
update public.community_products cp
set
  hp_score = scored.hp_score,
  hp_chemical_load = scored.chemical_load,
  hp_risk_factor = scored.risk_factor,
  hp_nutri_factor = scored.nutri_factor,
  hp_score_version = 2,
  updated_at = now()
from scored
where cp.id = scored.id;
