-- ══════════════════════════════════════════════════════════════════════
-- fix-phase32-batch.sql — Library approve→publish, household meal plans,
-- structured meal slots, allergy policy, substitutions RPC
-- Safe to re-run. Run after fix-phase29/31.
-- ══════════════════════════════════════════════════════════════════════

-- ── 1. Household shared meal plans ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.household_meal_plans (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id  uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  week_key      text NOT NULL,
  plan_data     jsonb NOT NULL DEFAULT '{}',
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, week_key)
);
CREATE INDEX IF NOT EXISTS idx_household_meal_plans_household ON public.household_meal_plans(household_id);
ALTER TABLE public.household_meal_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS household_meal_plans_members ON public.household_meal_plans;
CREATE POLICY household_meal_plans_members ON public.household_meal_plans
  FOR ALL TO authenticated
  USING (household_id = public._my_household_id())
  WITH CHECK (household_id = public._my_household_id());

-- ── 2. Structured meal plan slots (analytics / export) ─────────────────
CREATE TABLE IF NOT EXISTS public.meal_plan_slots (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_kind   text NOT NULL CHECK (owner_kind IN ('user', 'household')),
  owner_id     uuid NOT NULL,
  week_key     text NOT NULL,
  day_key      text NOT NULL,
  meal_type    text NOT NULL,
  recipe_id    uuid,
  recipe_name  text,
  slot_data    jsonb NOT NULL DEFAULT '{}',
  status       text NOT NULL DEFAULT 'planned',
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (owner_kind, owner_id, week_key, day_key, meal_type)
);
CREATE INDEX IF NOT EXISTS idx_meal_plan_slots_owner ON public.meal_plan_slots(owner_kind, owner_id, week_key);
ALTER TABLE public.meal_plan_slots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS meal_plan_slots_user ON public.meal_plan_slots;
CREATE POLICY meal_plan_slots_user ON public.meal_plan_slots
  FOR ALL TO authenticated
  USING (
    (owner_kind = 'user' AND owner_id = auth.uid())
    OR (owner_kind = 'household' AND owner_id = public._my_household_id())
  )
  WITH CHECK (
    (owner_kind = 'user' AND owner_id = auth.uid())
    OR (owner_kind = 'household' AND owner_id = public._my_household_id())
  );

CREATE OR REPLACE FUNCTION public._sync_meal_plan_slots(
  p_owner_kind text, p_owner_id uuid, p_week_key text, p_plan_data jsonb
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE d text; m text; day_obj jsonb; slot_rec jsonb; st text;
BEGIN
  DELETE FROM meal_plan_slots
  WHERE owner_kind = p_owner_kind AND owner_id = p_owner_id AND week_key = p_week_key;
  IF p_plan_data IS NULL OR p_plan_data = '{}'::jsonb THEN RETURN; END IF;
  FOR d, day_obj IN SELECT key, value FROM jsonb_each(p_plan_data)
  LOOP
    FOR m, slot_rec IN SELECT key, value FROM jsonb_each(day_obj)
    LOOP
      IF slot_rec IS NULL OR slot_rec = 'null'::jsonb THEN CONTINUE; END IF;
      st := COALESCE(slot_rec->>'status', 'planned');
      INSERT INTO meal_plan_slots (
        owner_kind, owner_id, week_key, day_key, meal_type,
        recipe_id, recipe_name, slot_data, status, updated_at
      ) VALUES (
        p_owner_kind, p_owner_id, p_week_key, d, m,
        NULLIF(COALESCE(slot_rec->>'recipe_id', slot_rec->>'id'), '')::uuid,
        COALESCE(slot_rec->>'name', slot_rec->>'recipe_name'),
        slot_rec, st, now()
      );
    END LOOP;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public._merge_meal_plan_jsonb(a jsonb, b jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(a, '{}'::jsonb) || COALESCE(b, '{}'::jsonb);
$$;

DROP FUNCTION IF EXISTS public.save_my_meal_plan(text, jsonb);
CREATE OR REPLACE FUNCTION public.save_my_meal_plan(p_week_key text, p_plan_data jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    INSERT INTO household_meal_plans (household_id, week_key, plan_data, updated_at)
    VALUES (h_id, p_week_key, COALESCE(p_plan_data, '{}'), now())
    ON CONFLICT (household_id, week_key)
    DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = now();
    PERFORM public._sync_meal_plan_slots('household', h_id, p_week_key, COALESCE(p_plan_data, '{}'));
    RETURN;
  END IF;
  INSERT INTO meal_plans (user_id, week_key, plan_data, updated_at)
  VALUES (auth.uid(), p_week_key, COALESCE(p_plan_data, '{}'), now())
  ON CONFLICT (user_id, week_key)
  DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = now();
  PERFORM public._sync_meal_plan_slots('user', auth.uid(), p_week_key, COALESCE(p_plan_data, '{}'));
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_my_meal_plan(text, jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.get_my_meal_plan(text);
CREATE OR REPLACE FUNCTION public.get_my_meal_plan(p_week_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h_id uuid; h_name text; plan jsonb; ts timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    SELECT h.name, COALESCE(hmp.plan_data, '{}'), hmp.updated_at
    INTO h_name, plan, ts
    FROM public.households h
    LEFT JOIN public.household_meal_plans hmp ON hmp.household_id = h.id AND hmp.week_key = p_week_key
    WHERE h.id = h_id;
    RETURN jsonb_build_object(
      'plan_data', COALESCE(plan, '{}'),
      'updated_at', COALESCE(ts, now()),
      'shared', true,
      'household_id', h_id,
      'household_name', h_name
    );
  END IF;
  SELECT COALESCE(mp.plan_data, '{}'), COALESCE(mp.updated_at, now())
  INTO plan, ts FROM public.meal_plans mp
  WHERE mp.user_id = auth.uid() AND mp.week_key = p_week_key;
  RETURN jsonb_build_object(
    'plan_data', COALESCE(plan, '{}'),
    'updated_at', COALESCE(ts, now()),
    'shared', false,
    'household_id', null,
    'household_name', null
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_meal_plan(text) TO authenticated;

-- Merge personal meal plans when joining a household (mirrors grocery merge)
CREATE OR REPLACE FUNCTION public.accept_household_invite(p_invite_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv public.household_invites%ROWTYPE;
  my_email text;
  personal jsonb;
  personal_checked jsonb;
  mp_rec record;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF public._my_household_id() IS NOT NULL THEN RAISE EXCEPTION 'Already in a household'; END IF;
  SELECT lower(email) INTO my_email FROM public.profiles WHERE id = auth.uid();
  SELECT * INTO inv FROM public.household_invites
  WHERE id = p_invite_id AND status = 'pending' AND expires_at > now() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invite not found or expired'; END IF;
  IF lower(inv.invitee_email) <> my_email THEN RAISE EXCEPTION 'Invite is for a different email'; END IF;
  SELECT list_data, checked INTO personal, personal_checked
  FROM public.grocery_lists WHERE user_id = auth.uid();
  UPDATE public.households SET
    grocery_list_data = public._merge_grocery_lists(grocery_list_data, personal),
    grocery_checked = grocery_checked || COALESCE(personal_checked, '[]'::jsonb),
    grocery_updated_at = now()
  WHERE id = inv.household_id;
  FOR mp_rec IN SELECT week_key, plan_data FROM public.meal_plans WHERE user_id = auth.uid()
  LOOP
    INSERT INTO public.household_meal_plans (household_id, week_key, plan_data, updated_at)
    VALUES (inv.household_id, mp_rec.week_key, mp_rec.plan_data, now())
    ON CONFLICT (household_id, week_key) DO UPDATE SET
      plan_data = public._merge_meal_plan_jsonb(household_meal_plans.plan_data, EXCLUDED.plan_data),
      updated_at = now();
    PERFORM public._sync_meal_plan_slots('household', inv.household_id, mp_rec.week_key,
      (SELECT plan_data FROM household_meal_plans WHERE household_id = inv.household_id AND week_key = mp_rec.week_key));
  END LOOP;
  INSERT INTO public.household_members (household_id, user_id, role)
  VALUES (inv.household_id, auth.uid(), 'member');
  UPDATE public.household_invites SET status = 'accepted' WHERE id = p_invite_id;
  DELETE FROM public.grocery_lists WHERE user_id = auth.uid();
  DELETE FROM public.meal_plans WHERE user_id = auth.uid();
END;
$$;

-- ── 3. Allergy policy on user profile ──────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS hide_unsafe_recipes boolean NOT NULL DEFAULT false;

DROP FUNCTION IF EXISTS public.get_my_allergy_settings();
CREATE OR REPLACE FUNCTION public.get_my_allergy_settings()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_hide boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT COALESCE(hide_unsafe_recipes, false) INTO v_hide FROM profiles WHERE id = auth.uid();
  RETURN jsonb_build_object('hide_unsafe_recipes', COALESCE(v_hide, false));
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_allergy_settings() TO authenticated;

DROP FUNCTION IF EXISTS public.update_my_allergy_settings(boolean);
CREATE OR REPLACE FUNCTION public.update_my_allergy_settings(p_hide_unsafe boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE profiles SET hide_unsafe_recipes = COALESCE(p_hide_unsafe, false) WHERE id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_my_allergy_settings(boolean) TO authenticated;

-- ── 4. Substitutions lookup RPC ────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_substitutions_lookup();
CREATE OR REPLACE FUNCTION public.get_substitutions_lookup()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_object_agg(k, arr) FROM (
      SELECT lower(trim(original)) AS k,
        jsonb_agg(jsonb_build_object(
          'substitute', substitute, 'ratio', ratio, 'notes', notes,
          'dietary_benefit', dietary_benefit, 'category', category
        ) ORDER BY id) AS arr
      FROM public.substitutions
      GROUP BY lower(trim(original))
    ) sub
  ), '{}'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_substitutions_lookup() TO anon, authenticated;

-- ── 5. Library submission approve → published profile ──────────────────
CREATE OR REPLACE FUNCTION public._publish_library_submission(sub public.library_profile_submissions)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; p jsonb; slug text;
BEGIN
  p := COALESCE(sub.payload, '{}');
  slug := COALESCE(NULLIF(trim(sub.slug), ''), NULLIF(trim(p->>'slug'), ''), lower(regexp_replace(COALESCE(p->>'name', 'profile'), '[^a-z0-9]+', '-', 'g')));
  IF sub.profile_type = 'ingredient' THEN
    INSERT INTO ingredient_profiles (
      slug, name, also_known_as, local_names, category, subcategory, image_url,
      origin_story, history, flavour_profile, how_to_buy, how_to_store, how_to_prep,
      when_to_add, common_mistakes, nutrition_notes, allergen, vegan, vegetarian,
      substitutes, chefs_notes, recommended_brand, seasonality, science_notes,
      cultural_use, baby_notes, pairings, preservation_notes, did_you_know,
      status, visibility, created_by
    ) VALUES (
      slug, COALESCE(p->>'name', 'Untitled'), p->>'also_known_as',
      CASE WHEN p ? 'local_names' THEN COALESCE(p->'local_names', '[]'::jsonb) ELSE '[]'::jsonb END,
      p->>'category', p->>'subcategory', p->>'image_url',
      p->>'origin_story', p->>'history', p->>'flavour_profile',
      p->>'how_to_buy', p->>'how_to_store', p->>'how_to_prep',
      p->>'when_to_add', p->>'common_mistakes', p->>'nutrition_notes', p->>'allergen',
      COALESCE((p->>'vegan')::boolean, false), COALESCE((p->>'vegetarian')::boolean, false),
      p->>'substitutes', p->>'chefs_notes', p->>'recommended_brand', p->>'seasonality',
      p->>'science_notes', p->>'cultural_use', p->>'baby_notes', p->>'pairings', p->>'preservation_notes',
      p->>'did_you_know', 'published', COALESCE(NULLIF(p->>'visibility', ''), 'public'), sub.user_id
    )
    ON CONFLICT (slug) DO UPDATE SET
      name = EXCLUDED.name, also_known_as = EXCLUDED.also_known_as, local_names = EXCLUDED.local_names,
      category = EXCLUDED.category, subcategory = EXCLUDED.subcategory, image_url = EXCLUDED.image_url,
      flavour_profile = EXCLUDED.flavour_profile, how_to_buy = EXCLUDED.how_to_buy,
      how_to_store = EXCLUDED.how_to_store, how_to_prep = EXCLUDED.how_to_prep,
      chefs_notes = EXCLUDED.chefs_notes, did_you_know = EXCLUDED.did_you_know,
      status = 'published', visibility = EXCLUDED.visibility, updated_at = now()
    RETURNING id INTO v_id;
  ELSIF sub.profile_type = 'spice' THEN
    INSERT INTO spice_profiles (slug, name, also_known_as, local_names, image_url, flavour_wheel, heat_level,
      whole_vs_ground, how_to_toast, blends, when_to_add, chefs_notes, did_you_know, status, visibility, created_by)
    VALUES (slug, COALESCE(p->>'name','Untitled'), p->>'also_known_as',
      CASE WHEN p ? 'local_names' THEN COALESCE(p->'local_names','[]'::jsonb) ELSE '[]'::jsonb END,
      p->>'image_url', COALESCE(p->>'flavour_wheel', p->>'flavour_profile'),
      COALESCE((p->>'heat_level')::int, 0), p->>'whole_vs_ground', p->>'how_to_toast', p->>'blends',
      p->>'when_to_add', p->>'chefs_notes', p->>'did_you_know', 'published',
      COALESCE(NULLIF(p->>'visibility',''),'public'), sub.user_id)
    ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, flavour_wheel = EXCLUDED.flavour_wheel,
      heat_level = EXCLUDED.heat_level, chefs_notes = EXCLUDED.chefs_notes, status = 'published', updated_at = now()
    RETURNING id INTO v_id;
  ELSIF sub.profile_type = 'tool' THEN
    INSERT INTO tool_profiles (slug, name, also_known_as, tool_category, image_url, what_its_for, how_to_use,
      how_to_care, what_to_look_for, price_range, chefs_notes, did_you_know, status, visibility, created_by)
    VALUES (slug, COALESCE(p->>'name','Untitled'), p->>'also_known_as', p->>'tool_category', p->>'image_url',
      p->>'what_its_for', p->>'how_to_use', p->>'how_to_care', p->>'what_to_look_for', p->>'price_range',
      p->>'chefs_notes', p->>'did_you_know', 'published', COALESCE(NULLIF(p->>'visibility',''),'public'), sub.user_id)
    ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, tool_category = EXCLUDED.tool_category,
      what_its_for = EXCLUDED.what_its_for, status = 'published', updated_at = now()
    RETURNING id INTO v_id;
  ELSIF sub.profile_type = 'cut' THEN
    INSERT INTO cut_profiles (slug, name, also_known_as, international_names, protein_type, image_url,
      location_on_animal, characteristics, how_to_clean, how_to_prep, best_cooking_methods, chefs_notes, did_you_know,
      status, visibility, created_by)
    VALUES (slug, COALESCE(p->>'name','Untitled'), p->>'also_known_as',
      CASE WHEN p ? 'international_names' THEN COALESCE(p->'international_names','[]'::jsonb) ELSE '[]'::jsonb END,
      p->>'protein_type', p->>'image_url', p->>'location_on_animal', p->>'characteristics',
      p->>'how_to_clean', p->>'how_to_prep', p->>'best_cooking_methods', p->>'chefs_notes', p->>'did_you_know',
      'published', COALESCE(NULLIF(p->>'visibility',''),'public'), sub.user_id)
    ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, protein_type = EXCLUDED.protein_type,
      characteristics = EXCLUDED.characteristics, status = 'published', updated_at = now()
    RETURNING id INTO v_id;
  ELSIF sub.profile_type = 'preservation' THEN
    INSERT INTO preservation_profiles (slug, name, technique_type, image_url, what_it_is, best_for,
      equipment_needed, step_by_step, safety_notes, shelf_life, chefs_notes, did_you_know, status, visibility, created_by)
    VALUES (slug, COALESCE(p->>'name','Untitled'), p->>'technique_type', p->>'image_url', p->>'what_it_is',
      p->>'best_for', p->>'equipment_needed',
      CASE WHEN p ? 'step_by_step' THEN COALESCE(p->'step_by_step','[]'::jsonb) ELSE '[]'::jsonb END,
      p->>'safety_notes', p->>'shelf_life', p->>'chefs_notes', p->>'did_you_know', 'published',
      COALESCE(NULLIF(p->>'visibility',''),'public'), sub.user_id)
    ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, technique_type = EXCLUDED.technique_type,
      what_it_is = EXCLUDED.what_it_is, status = 'published', updated_at = now()
    RETURNING id INTO v_id;
  ELSE
    RAISE EXCEPTION 'unknown_profile_type';
  END IF;
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_review_library_submission(uuid, text, text);
CREATE OR REPLACE FUNCTION public.admin_review_library_submission(
  p_id uuid, p_action text, p_notes text DEFAULT NULL
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE sub public.library_profile_submissions%ROWTYPE; pub_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  SELECT * INTO sub FROM library_profile_submissions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  IF p_action = 'reject' THEN
    UPDATE library_profile_submissions SET status = 'rejected', reviewer_notes = p_notes, reviewed_at = now() WHERE id = p_id;
    RETURN true;
  ELSIF p_action = 'approve' THEN
    pub_id := public._publish_library_submission(sub);
    UPDATE library_profile_submissions SET status = 'approved', reviewer_notes = p_notes, reviewed_at = now(),
      payload = sub.payload || jsonb_build_object('published_profile_id', pub_id::text)
    WHERE id = p_id;
    RETURN true;
  END IF;
  RAISE EXCEPTION 'invalid_action';
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_library_submission(uuid, text, text) TO authenticated;

SELECT 'fix-phase32-batch.sql complete' AS status;
