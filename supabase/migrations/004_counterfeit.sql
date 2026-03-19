-- Turkish Ministry counterfeit/adulterated products
CREATE TABLE public.counterfeit_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_name TEXT NOT NULL,
  product_name TEXT NOT NULL,
  category TEXT,
  violation_type TEXT NOT NULL,
  violation_detail TEXT,
  province TEXT,
  detection_date DATE,
  barcode TEXT,
  source_url TEXT,
  synced_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_counterfeit_barcode
  ON public.counterfeit_products(barcode) WHERE barcode IS NOT NULL;

CREATE INDEX idx_counterfeit_brand
  ON public.counterfeit_products(brand_name);

ALTER TABLE public.counterfeit_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read counterfeit list"
  ON public.counterfeit_products FOR SELECT
  TO authenticated USING (true);
