-- ══════════════════════════════════════════════════════════════════════
-- fix-phase4-batch.sql — Phase 4 non-AI surfaces. Safe to re-run.
-- Contributor follows, Friends visibility, family reference lists (admin).
-- Run after fix-phase3-batch.sql. Includes baby food stage column/RPC.
-- ══════════════════════════════════════════════════════════════════════

-- ── Baby food stage (family profiles) ────────────────────────────────
ALTER TABLE public.family_profiles
  ADD COLUMN IF NOT EXISTS baby_food_stage text;

-- ── Contributor follows ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contributor_follows (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (follower_id, following_id),
  CHECK (follower_id <> following_id)
);
ALTER TABLE public.contributor_follows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own follows" ON public.contributor_follows;
CREATE POLICY "Users manage own follows"
  ON public.contributor_follows FOR ALL TO authenticated
  USING (follower_id = auth.uid())
  WITH CHECK (follower_id = auth.uid());
GRANT SELECT, INSERT, DELETE ON public.contributor_follows TO authenticated;

-- ── Family profile reference lists (admin-managed) ─────────────────
CREATE TABLE IF NOT EXISTS public.family_reference_lists (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category   text NOT NULL,
  value      text NOT NULL,
  sort_order int  NOT NULL DEFAULT 0,
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (category, value)
);
ALTER TABLE public.family_reference_lists ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone reads active reference lists" ON public.family_reference_lists;
CREATE POLICY "Anyone reads active reference lists"
  ON public.family_reference_lists FOR SELECT TO anon, authenticated
  USING (is_active = true);
DROP POLICY IF EXISTS "Admins manage reference lists" ON public.family_reference_lists;
CREATE POLICY "Admins manage reference lists"
  ON public.family_reference_lists FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON public.family_reference_lists TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.family_reference_lists TO authenticated;

INSERT INTO public.family_reference_lists (category, value, sort_order) VALUES
  ('relationship', 'Self', 1),
  ('relationship', 'Partner', 2),
  ('relationship', 'Child', 3),
  ('relationship', 'Parent', 4),
  ('relationship', 'Sibling', 5),
  ('relationship', 'Grandparent', 6),
  ('relationship', 'Grandchild', 7),
  ('relationship', 'Guest', 8),
  ('relationship', 'Other', 9),
  ('age_group', '0–6 months', 1),
  ('age_group', '6–12 months', 2),
  ('age_group', '1–3 years', 3),
  ('age_group', '4–7 years', 4),
  ('age_group', '8–12 years', 5),
  ('age_group', '13–17 years', 6),
  ('age_group', '18–64 years', 7),
  ('age_group', '65+ years', 8),
  ('dietary_needs', 'Vegetarian', 1),
  ('dietary_needs', 'Vegan', 2),
  ('dietary_needs', 'Gluten-free', 3),
  ('dietary_needs', 'Dairy-free', 4),
  ('dietary_needs', 'Halal', 5),
  ('dietary_needs', 'Kosher', 6),
  ('dietary_needs', 'Low sodium', 7),
  ('dietary_needs', 'Low sugar', 8),
  ('allergies', 'Peanuts', 1),
  ('allergies', 'Tree nuts', 2),
  ('allergies', 'Shellfish', 3),
  ('allergies', 'Fish', 4),
  ('allergies', 'Eggs', 5),
  ('allergies', 'Dairy', 6),
  ('allergies', 'Wheat / gluten', 7),
  ('allergies', 'Soy', 8),
  ('allergies', 'Sesame', 9),
  ('health_conditions', 'Diabetes', 1),
  ('health_conditions', 'High cholesterol', 2),
  ('health_conditions', 'Hypertension', 3),
  ('health_conditions', 'Elderly / reduced mobility', 4),
  ('health_conditions', 'Pregnancy', 5),
  ('health_conditions', 'New parent', 6)
ON CONFLICT (category, value) DO NOTHING;

-- Drop overloaded RPCs before recreate
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN (
               'upsert_family_profile',
               'toggle_contributor_follow',
               'is_following_contributor',
               'get_contributor_follow_stats',
               'get_family_reference_lists',
               'admin_upsert_family_reference',
               'admin_delete_family_reference',
               'get_public_recipe',
               'get_approved_recipes'
             )
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

-- Family profile upsert with baby food stage
CREATE OR REPLACE FUNCTION public.upsert_family_profile(
  p_id                uuid    DEFAULT NULL,
  p_name              text    DEFAULT '',
  p_relationship      text    DEFAULT 'guest',
  p_age_group         text    DEFAULT 'adult',
  p_allergies         jsonb   DEFAULT '[]',
  p_spice_preference  text    DEFAULT 'medium',
  p_dietary_needs     jsonb   DEFAULT '[]',
  p_health_conditions text[]  DEFAULT '{}',
  p_notes             text    DEFAULT '',
  p_baby_food_stage   text    DEFAULT NULL
)
RETURNS public.family_profiles
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.family_profiles;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.family_profiles (
      user_id, name, relationship, age_group, allergies, spice_preference,
      dietary_needs, health_conditions, notes, baby_food_stage
    ) VALUES (
      auth.uid(), p_name, p_relationship, p_age_group, p_allergies, p_spice_preference,
      p_dietary_needs, p_health_conditions, p_notes, p_baby_food_stage
    ) RETURNING * INTO result;
  ELSE
    UPDATE public.family_profiles SET
      name = p_name, relationship = p_relationship, age_group = p_age_group,
      allergies = p_allergies, spice_preference = p_spice_preference,
      dietary_needs = p_dietary_needs, health_conditions = p_health_conditions,
      notes = p_notes, baby_food_stage = p_baby_food_stage
    WHERE id = p_id AND user_id = auth.uid()
    RETURNING * INTO result;
  END IF;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_family_profile(
  uuid, text, text, text, jsonb, text, jsonb, text[], text, text
) TO authenticated;

-- Follow RPCs
CREATE OR REPLACE FUNCTION public.toggle_contributor_follow(p_username text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_target uuid;
  v_following boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT id INTO v_target FROM public.profiles WHERE lower(username) = lower(trim(p_username)) LIMIT 1;
  IF v_target IS NULL THEN RAISE EXCEPTION 'user_not_found'; END IF;
  IF v_target = auth.uid() THEN RAISE EXCEPTION 'cannot_follow_self'; END IF;
  IF EXISTS (SELECT 1 FROM public.contributor_follows WHERE follower_id = auth.uid() AND following_id = v_target) THEN
    DELETE FROM public.contributor_follows WHERE follower_id = auth.uid() AND following_id = v_target;
    v_following := false;
  ELSE
    INSERT INTO public.contributor_follows (follower_id, following_id) VALUES (auth.uid(), v_target);
    v_following := true;
  END IF;
  RETURN jsonb_build_object('following', v_following, 'username', p_username);
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_contributor_follow(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_following_contributor(p_username text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_target uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN false; END IF;
  SELECT id INTO v_target FROM public.profiles WHERE lower(username) = lower(trim(p_username)) LIMIT 1;
  IF v_target IS NULL THEN RETURN false; END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.contributor_follows
     WHERE follower_id = auth.uid() AND following_id = v_target
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.is_following_contributor(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_contributor_follow_stats(p_username text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_target uuid; v_followers bigint; v_following boolean;
BEGIN
  SELECT id INTO v_target FROM public.profiles WHERE lower(username) = lower(trim(p_username)) LIMIT 1;
  IF v_target IS NULL THEN RETURN jsonb_build_object('followers', 0, 'following', false); END IF;
  SELECT COUNT(*) INTO v_followers FROM public.contributor_follows WHERE following_id = v_target;
  v_following := public.is_following_contributor(p_username);
  RETURN jsonb_build_object('followers', v_followers, 'following', v_following);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_contributor_follow_stats(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_family_reference_lists(p_category text DEFAULT NULL)
RETURNS TABLE (category text, value text, sort_order int)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT category, value, sort_order
    FROM public.family_reference_lists
   WHERE is_active = true
     AND (p_category IS NULL OR category = p_category)
   ORDER BY category, sort_order, value;
$$;
GRANT EXECUTE ON FUNCTION public.get_family_reference_lists(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_family_reference(
  p_id uuid, p_category text, p_value text, p_sort_order int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.family_reference_lists (category, value, sort_order)
    VALUES (p_category, trim(p_value), COALESCE(p_sort_order, 0))
    ON CONFLICT (category, value) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = true
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.family_reference_lists SET
      category = p_category, value = trim(p_value), sort_order = COALESCE(p_sort_order, sort_order)
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_family_reference(uuid, text, text, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_delete_family_reference(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.family_reference_lists SET is_active = false WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_family_reference(uuid) TO authenticated;

-- Friends visibility: extend public recipe access for followers
CREATE OR REPLACE FUNCTION public.get_public_recipe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row   public.submitted_recipes%ROWTYPE;
  v_user  text;
  v_uid   uuid;
BEGIN
  IF p_id IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO v_row FROM public.submitted_recipes WHERE id = p_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT username INTO v_user FROM public.profiles WHERE id = v_row.user_id;
  v_uid := auth.uid();
  IF is_admin()
     OR (v_uid IS NOT NULL AND v_row.user_id = v_uid)
     OR (v_row.status = 'approved' AND v_row.visibility = 'Public')
     OR (
       v_row.status = 'approved' AND v_row.visibility = 'Friends'
       AND v_uid IS NOT NULL
       AND EXISTS (
         SELECT 1 FROM public.contributor_follows
          WHERE follower_id = v_uid AND following_id = v_row.user_id
       )
     )
  THEN
    RETURN to_jsonb(v_row) || jsonb_build_object('username', v_user);
  END IF;
  RETURN NULL;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_public_recipe(uuid) TO anon, authenticated;

-- Approved recipes: include Friends-only from followed contributors when signed in
CREATE OR REPLACE FUNCTION public.get_approved_recipes(
  p_category text DEFAULT NULL,
  p_spice    text DEFAULT NULL,
  p_dietary  text DEFAULT NULL,
  p_search   text DEFAULT NULL,
  p_limit    int  DEFAULT 50,
  p_offset   int  DEFAULT 0
)
RETURNS TABLE (
  id             uuid,
  recipe_name    text,
  native_title   text,
  category       text,
  spice_level    text,
  dietary_tags   text[],
  origin_country text,
  image_url      text,
  credit_name    text,
  credit_handle  text,
  submitted_at   timestamptz,
  username       text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.native_title, sr.category,
         sr.spice_level, sr.dietary_tags, sr.origin_country,
         sr.image_url, sr.credit_name, sr.credit_handle,
         sr.submitted_at, p.username
    FROM public.submitted_recipes sr
    LEFT JOIN public.profiles p ON p.id = sr.user_id
   WHERE sr.status = 'approved'
     AND (
       sr.visibility = 'Public'
       OR (
         sr.visibility = 'Friends'
         AND auth.uid() IS NOT NULL
         AND EXISTS (
           SELECT 1 FROM public.contributor_follows cf
            WHERE cf.follower_id = auth.uid() AND cf.following_id = sr.user_id
         )
       )
     )
     AND (p_category IS NULL OR sr.category = p_category)
     AND (p_spice    IS NULL OR sr.spice_level = p_spice)
     AND (p_dietary  IS NULL OR p_dietary = ANY(sr.dietary_tags))
     AND (p_search   IS NULL OR sr.recipe_name ILIKE '%' || p_search || '%')
   ORDER BY sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_approved_recipes(text,text,text,text,int,int) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase4-batch.sql complete' AS status;
