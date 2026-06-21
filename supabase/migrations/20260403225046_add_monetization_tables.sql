-- user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
  id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_tier       TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
  rc_customer_id          TEXT,
  subscription_expires_at TIMESTAMPTZ,
  daily_scan_limit        INT NOT NULL DEFAULT 2,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'user_profiles' AND policyname = 'users_read_own_profile'
  ) THEN
    CREATE POLICY "users_read_own_profile" ON user_profiles
      FOR SELECT USING (auth.uid() = id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'user_profiles' AND policyname = 'users_update_own_profile'
  ) THEN
    CREATE POLICY "users_update_own_profile" ON user_profiles
      FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Backfill profiles for existing users
INSERT INTO user_profiles (id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT id FROM user_profiles)
ON CONFLICT DO NOTHING;

-- daily_scans table
CREATE TABLE IF NOT EXISTS daily_scans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scan_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  scan_count  INT NOT NULL DEFAULT 0,
  bonus_count INT NOT NULL DEFAULT 0,
  UNIQUE(user_id, scan_date)
);

ALTER TABLE daily_scans ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'daily_scans' AND policyname = 'users_read_own_scans'
  ) THEN
    CREATE POLICY "users_read_own_scans" ON daily_scans
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

-- RPC: check_and_increment_scan
CREATE OR REPLACE FUNCTION check_and_increment_scan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_tier TEXT;
  v_limit INT;
  v_count INT;
  v_bonus INT;
BEGIN
  SELECT subscription_tier, daily_scan_limit
    INTO v_tier, v_limit
    FROM user_profiles WHERE id = p_user_id;

  IF v_tier IS NULL THEN
    INSERT INTO user_profiles (id) VALUES (p_user_id);
    v_tier := 'free';
    v_limit := 2;
  END IF;

  IF v_tier = 'premium' THEN
    RETURN jsonb_build_object('allowed', true, 'remaining', -1, 'is_premium', true);
  END IF;

  INSERT INTO daily_scans (user_id, scan_date, scan_count, bonus_count)
    VALUES (p_user_id, CURRENT_DATE, 0, 0)
    ON CONFLICT (user_id, scan_date) DO NOTHING;

  SELECT scan_count, bonus_count INTO v_count, v_bonus
    FROM daily_scans WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  IF v_count < v_limit + v_bonus THEN
    UPDATE daily_scans SET scan_count = scan_count + 1
      WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;
    RETURN jsonb_build_object(
      'allowed', true,
      'remaining', v_limit + v_bonus - v_count - 1,
      'is_premium', false
    );
  END IF;

  RETURN jsonb_build_object('allowed', false, 'remaining', 0, 'is_premium', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: grant_bonus_scan
CREATE OR REPLACE FUNCTION grant_bonus_scan(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_bonus INT;
BEGIN
  INSERT INTO daily_scans (user_id, scan_date, scan_count, bonus_count)
    VALUES (p_user_id, CURRENT_DATE, 0, 0)
    ON CONFLICT (user_id, scan_date) DO NOTHING;

  SELECT bonus_count INTO v_bonus
    FROM daily_scans WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  IF v_bonus >= 3 THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'max_bonus_reached');
  END IF;

  UPDATE daily_scans SET bonus_count = bonus_count + 1
    WHERE user_id = p_user_id AND scan_date = CURRENT_DATE;

  RETURN jsonb_build_object('granted', true, 'bonus_remaining', 2 - v_bonus);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
