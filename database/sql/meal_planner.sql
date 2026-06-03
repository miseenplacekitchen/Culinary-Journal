-- ══════════════════════════════════════════════════════════════════════
-- Meal Planner — The Culinary Journal
-- Table/RPC shapes match meal-planner.html exactly:
--   family_profiles: id, user_id, name, relationship, dietary_needs (jsonb),
--                    allergies (jsonb), spice_preference, created_at
-- RPCs: get_approved_recipes(p_limit), get_my_family_profiles()
-- ══════════════════════════════════════════════════════════════════════

-- ── Family profiles table ─────────────────────────────────────────────
-- Columns match what the frontend reads: relationship, dietary_needs,
-- allergies, spice_preference (not age/avatar/dietary_requirements)
CREATE TABLE IF NOT EXISTS family_profiles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             text NOT NULL,
  relationship     text DEFAULT 'other',
  dietary_needs    jsonb NOT NULL DEFAULT '[]',
  allergies        jsonb NOT NULL DEFAULT '[]',
  spice_preference text DEFAULT 'medium',
  created_at       timestamptz NOT NULL DEFAULT NOW()
);
-- Guards for existing table missing columns
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS name             text;
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS relationship     text DEFAULT 'other';
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS dietary_needs    jsonb;
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS allergies        jsonb;
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS spice_preference text DEFAULT 'medium';
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS created_at       timestamptz;
-- Drop any old default before changing column type, then convert and restore
ALTER TABLE family_profiles ALTER COLUMN dietary_needs DROP DEFAULT;
ALTER TABLE family_profiles ALTER COLUMN allergies     DROP DEFAULT;
ALTER TABLE family_profiles ALTER COLUMN dietary_needs TYPE jsonb
  USING COALESCE(to_jsonb(dietary_needs), '[]'::jsonb);
ALTER TABLE family_profiles ALTER COLUMN allergies TYPE jsonb
  USING COALESCE(to_jsonb(allergies), '[]'::jsonb);
ALTER TABLE family_profiles ALTER COLUMN dietary_needs SET DEFAULT '[]'::jsonb;
ALTER TABLE family_profiles ALTER COLUMN allergies     SET DEFAULT '[]'::jsonb;
-- Set defaults on existing null rows
UPDATE family_profiles SET dietary_needs = '[]'::jsonb WHERE dietary_needs IS NULL;
UPDATE family_profiles SET allergies     = '[]'::jsonb WHERE allergies     IS NULL;

ALTER TABLE family_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own family profiles" ON family_profiles;
CREATE POLICY "users manage own family profiles" ON family_profiles
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── get_approved_recipes(p_limit) ─────────────────────────────────────
-- Returns approved recipes for meal planner recipe picker
DROP FUNCTION IF EXISTS get_approved_recipes(int);
DROP FUNCTION IF EXISTS get_approved_recipes(text, int);
CREATE FUNCTION get_approved_recipes(
  p_category text DEFAULT NULL,
  p_limit    int  DEFAULT 100
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN COALESCE(
    (SELECT jsonb_agg(r ORDER BY r.recipe_name ASC)
     FROM (
       SELECT id,
              recipe_name,
              recipe_name   AS name,
              category,
              origin_country,
              spice_level,
              image_url,
              prep_time_minutes,
              cook_time_minutes,
              servings,
              ingredients,
              dietary_tags,
              occasion_tags,
              health_tags
       FROM submitted_recipes
       WHERE status = 'approved'
         AND (p_category IS NULL OR category = p_category)
       LIMIT p_limit
     ) r),
    '[]'::jsonb
  );
END; $$;
REVOKE ALL ON FUNCTION get_approved_recipes(text, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_approved_recipes(text, int) TO anon, authenticated;

SELECT 'Meal planner ready' AS status;

-- ── Meal plans table + RPCs ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.meal_plans (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_key   text        NOT NULL,
  plan_data  jsonb       NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, week_key)
);
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own meal plans" ON public.meal_plans;
CREATE POLICY "users manage own meal plans" ON public.meal_plans
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP FUNCTION IF EXISTS public.save_my_meal_plan(text, jsonb);
CREATE FUNCTION public.save_my_meal_plan(p_week_key text, p_plan_data jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  INSERT INTO meal_plans (user_id, week_key, plan_data, updated_at)
  VALUES (auth.uid(), p_week_key, p_plan_data, NOW())
  ON CONFLICT (user_id, week_key)
  DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = NOW();
END; $$;
REVOKE ALL ON FUNCTION public.save_my_meal_plan(text, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.save_my_meal_plan(text, jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.get_my_meal_plan(text);
CREATE FUNCTION public.get_my_meal_plan(p_week_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN (
    SELECT plan_data FROM meal_plans
    WHERE user_id = auth.uid() AND week_key = p_week_key
  );
END; $$;
REVOKE ALL ON FUNCTION public.get_my_meal_plan(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_my_meal_plan(text) TO authenticated;

SELECT 'Meal planner persistence ready' AS status;
