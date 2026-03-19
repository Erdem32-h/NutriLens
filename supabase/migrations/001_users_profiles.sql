-- User profiles extending Supabase auth.users
CREATE TABLE public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  selected_allergens JSONB DEFAULT '[]'::jsonb,
  diet_vegan BOOLEAN DEFAULT FALSE,
  diet_vegetarian BOOLEAN DEFAULT FALSE,
  diet_gluten_free BOOLEAN DEFAULT FALSE,
  diet_halal BOOLEAN DEFAULT FALSE,
  filter_palm_oil BOOLEAN DEFAULT FALSE,
  filter_canola_oil BOOLEAN DEFAULT FALSE,
  filter_cotton_oil BOOLEAN DEFAULT FALSE,
  filter_soy_oil BOOLEAN DEFAULT FALSE,
  filter_aspartame BOOLEAN DEFAULT FALSE,
  filter_msg BOOLEAN DEFAULT FALSE,
  filter_corn_syrup BOOLEAN DEFAULT FALSE,
  language TEXT DEFAULT 'tr',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: users can only access their own profile
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  USING (auth.uid() = id);

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
