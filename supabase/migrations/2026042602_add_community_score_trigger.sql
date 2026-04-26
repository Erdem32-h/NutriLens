create or replace function public.recalculate_community_product_hp_score()
returns trigger
language plpgsql
as $$
declare
  normalized_text text;
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
  has_critical boolean;
begin
  normalized_text := translate(
    lower(coalesce(new.ingredients_text, '')),
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

  risk_factor :=
    least(sugars / 22.5, 1) * 100 * 0.40 +
    least(salt_value / 2.4, 1) * 100 * 0.25 +
    least(saturated_fat / 10.0, 1) * 100 * 0.35;

  nutri_factor :=
    least(fiber / 6.0, 1) * 100 * 0.30 +
    least(proteins / 15.0, 1) * 100 * 0.30 +
    (
      case new.nova_group
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

  ingredient_quality_penalty :=
    least(
      case when has_added_sugar then 18 else 0 end +
      case when has_refined_flour then 12 else 0 end +
      case when has_added_sugar and has_refined_flour then 10 else 0 end,
      35
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

  new.hp_chemical_load := round(chemical_load, 2);
  new.hp_risk_factor := round(risk_factor, 2);
  new.hp_nutri_factor := round(nutri_factor, 2);
  new.hp_score_version := 2;
  new.hp_score := case
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
  end;
  new.updated_at := now();

  return new;
end;
$$;

drop trigger if exists trg_recalculate_community_product_hp_score on public.community_products;

create trigger trg_recalculate_community_product_hp_score
before insert or update of ingredients_text, additives_tags, nutriments, nova_group
on public.community_products
for each row
execute function public.recalculate_community_product_hp_score();

