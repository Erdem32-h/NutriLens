-- Cached food products from Open Food Facts
CREATE TABLE public.food_products (
  barcode TEXT PRIMARY KEY,
  product_name TEXT,
  brands TEXT,
  image_url TEXT,
  ingredients_text TEXT,
  allergens_tags JSONB DEFAULT '[]'::jsonb,
  additives_tags JSONB DEFAULT '[]'::jsonb,
  nova_group INTEGER CHECK (nova_group BETWEEN 1 AND 4),
  nutriscore_grade TEXT,
  nutriments JSONB DEFAULT '{}'::jsonb,
  categories_tags JSONB DEFAULT '[]'::jsonb,
  countries_tags JSONB DEFAULT '[]'::jsonb,
  hp_score NUMERIC(4,2),
  hp_chemical_load NUMERIC(5,2),
  hp_risk_factor NUMERIC(5,2),
  hp_nutri_factor NUMERIC(5,2),
  off_last_modified TIMESTAMPTZ,
  cached_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.food_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read products"
  ON public.food_products FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert products"
  ON public.food_products FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update products"
  ON public.food_products FOR UPDATE
  TO authenticated USING (true);

-- Food additives reference table
CREATE TABLE public.additives (
  id TEXT PRIMARY KEY,
  e_number TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_tr TEXT,
  category TEXT NOT NULL,
  risk_level INTEGER NOT NULL CHECK (risk_level BETWEEN 1 AND 5),
  risk_label TEXT NOT NULL,
  description_en TEXT,
  description_tr TEXT,
  efsa_status TEXT,
  turkish_codex_status TEXT,
  max_daily_intake TEXT,
  source TEXT,
  is_vegan BOOLEAN DEFAULT TRUE,
  is_vegetarian BOOLEAN DEFAULT TRUE,
  is_halal BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.additives ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read additives"
  ON public.additives FOR SELECT
  TO authenticated USING (true);

-- Allergens reference table
CREATE TABLE public.allergens (
  id TEXT PRIMARY KEY,
  name_en TEXT NOT NULL,
  name_tr TEXT NOT NULL,
  category TEXT,
  icon_name TEXT,
  severity_note TEXT
);

ALTER TABLE public.allergens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read allergens"
  ON public.allergens FOR SELECT
  TO authenticated USING (true);
