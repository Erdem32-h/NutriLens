-- Scan history
CREATE TABLE public.scan_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  barcode TEXT NOT NULL,
  scanned_at TIMESTAMPTZ DEFAULT now(),
  hp_score_at_scan NUMERIC(4,2),
  compatibility_result JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_scan_history_user ON public.scan_history(user_id, scanned_at DESC);

ALTER TABLE public.scan_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own history"
  ON public.scan_history FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own history"
  ON public.scan_history FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own history"
  ON public.scan_history FOR DELETE USING (auth.uid() = user_id);

-- Favorites
CREATE TABLE public.favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  barcode TEXT NOT NULL,
  added_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, barcode)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own favorites"
  ON public.favorites FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own favorites"
  ON public.favorites FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites"
  ON public.favorites FOR DELETE USING (auth.uid() = user_id);

-- Blacklist
CREATE TABLE public.blacklist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  barcode TEXT NOT NULL,
  reason TEXT,
  added_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, barcode)
);

ALTER TABLE public.blacklist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own blacklist"
  ON public.blacklist FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own blacklist"
  ON public.blacklist FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own blacklist"
  ON public.blacklist FOR DELETE USING (auth.uid() = user_id);
