-- ══════════════════════════════════════════════════════════════════════
-- fix-phase33-batch.sql — Engagement saves, sync conflicts, regional hints
-- Safe to re-run. Run after fix-phase32-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

-- ── 1. Recipe engagement (most-saved ranking) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.recipe_engagement (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id   uuid NOT NULL REFERENCES public.submitted_recipes(id) ON DELETE CASCADE,
  user_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type  text NOT NULL CHECK (event_type IN ('save', 'collection_add', 'print')),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_recipe_engagement_recipe ON public.recipe_engagement(recipe_id, event_type);
CREATE INDEX IF NOT EXISTS idx_recipe_engagement_created ON public.recipe_engagement(created_at DESC);
ALTER TABLE public.recipe_engagement ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recipe_engagement_insert ON public.recipe_engagement;
CREATE POLICY recipe_engagement_insert ON public.recipe_engagement
  FOR INSERT TO authenticated WITH CHECK (user_id IS NULL OR user_id = auth.uid());
DROP POLICY IF EXISTS recipe_engagement_read ON public.recipe_engagement;
CREATE POLICY recipe_engagement_read ON public.recipe_engagement
  FOR SELECT TO authenticated, anon USING (true);

CREATE OR REPLACE FUNCTION public._record_recipe_engagement(p_recipe_id uuid, p_event_type text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_recipe_id IS NULL THEN RETURN; END IF;
  INSERT INTO public.recipe_engagement (recipe_id, user_id, event_type)
  VALUES (p_recipe_id, auth.uid(), COALESCE(NULLIF(btrim(p_event_type), ''), 'save'));
END;
$$;

DROP FUNCTION IF EXISTS public.record_recipe_engagement(uuid, text);
CREATE FUNCTION public.record_recipe_engagement(p_recipe_id uuid, p_event_type text DEFAULT 'save')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  PERFORM public._record_recipe_engagement(p_recipe_id, p_event_type);
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_recipe_engagement(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.get_most_saved_recipes(int);
CREATE FUNCTION public.get_most_saved_recipes(p_limit int DEFAULT 12)
RETURNS TABLE (
  id uuid, recipe_name text, category text, origin_country text,
  image_url text, save_count bigint
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT r.id, r.recipe_name, r.category, r.origin_country, r.image_url,
         COUNT(e.id)::bigint AS save_count
  FROM public.submitted_recipes r
  JOIN public.recipe_engagement e ON e.recipe_id = r.id
  WHERE r.status = 'approved'
  GROUP BY r.id
  ORDER BY save_count DESC, r.recipe_name
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 12), 50));
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_most_saved_recipes(int) TO anon, authenticated;

-- Record saves when recipes are added to collections
CREATE OR REPLACE FUNCTION public.add_to_collection(p_collection_id uuid, p_recipe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.collections WHERE id=p_collection_id AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  INSERT INTO public.collection_recipes (collection_id, recipe_id) VALUES (p_collection_id, p_recipe_id)
  ON CONFLICT DO NOTHING;
  PERFORM public._record_recipe_engagement(p_recipe_id, 'collection_add');
END;
$$;

-- ── 2. Regional ingredient hints ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.regional_ingredient_hints (
  id          serial PRIMARY KEY,
  region_key  text NOT NULL UNIQUE,
  region_name text NOT NULL,
  hints       jsonb NOT NULL DEFAULT '[]'::jsonb,
  tip         text
);
ALTER TABLE public.regional_ingredient_hints ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS regional_hints_read ON public.regional_ingredient_hints;
CREATE POLICY regional_hints_read ON public.regional_ingredient_hints
  FOR SELECT TO anon, authenticated USING (true);

INSERT INTO public.regional_ingredient_hints (region_key, region_name, hints, tip) VALUES
  ('india', 'India', '["turmeric","cumin","coriander","mustard seeds","curry leaves","ghee","basmati rice","lentils","coconut"]', 'Visit an Indian grocer for whole spices — they stay fresher longer than ground.'),
  ('kerala', 'Kerala', '["coconut oil","curry leaves","black pepper","tamarind","jaggery","banana","jackfruit","coconut milk"]', 'Coconut oil is the default cooking fat in many Kerala dishes.'),
  ('middle-east', 'Middle East', '["tahini","sumac","za''atar","pomegranate molasses","bulgur","flatbread","lamb","yoghurt"]', 'Look for halal butchers and Middle Eastern bakeries for fresh flatbread.'),
  ('italy', 'Italy', '["olive oil","parmesan","san marzano tomatoes","basil","arborio rice","polenta","balsamic"]', 'Buy Parmigiano-Reggiano in a wedge — pre-grated loses aroma quickly.'),
  ('mexico', 'Mexico', '["corn tortillas","dried chillies","cilantro","lime","masa harina","queso fresco","avocado"]', 'Dried ancho and guajillo chillies keep for months and deepen sauces.'),
  ('japan', 'Japan', '["soy sauce","mirin","dashi","rice vinegar","nori","miso","short-grain rice"]', 'A good dashi stock transforms simple soups and simmered dishes.'),
  ('australia', 'Australia', '["macadamia","wattleseed","lemon myrtle","finger lime","kangaroo","barramundi"]', 'Farmers markets are ideal for native herbs and seasonal produce.'),
  ('uk', 'United Kingdom', '["self-raising flour","caster sugar","black pudding","horseradish","marmite","double cream"]', 'Seasonal veg boxes help with roast dinner planning.')
ON CONFLICT (region_key) DO UPDATE SET
  region_name = EXCLUDED.region_name,
  hints = EXCLUDED.hints,
  tip = EXCLUDED.tip;

DROP FUNCTION IF EXISTS public.get_regional_ingredient_hints(text);
CREATE FUNCTION public.get_regional_ingredient_hints(p_region text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE out jsonb := '[]'::jsonb;
BEGIN
  IF p_region IS NULL OR btrim(p_region) = '' THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'region_key', region_key, 'region_name', region_name,
      'hints', hints, 'tip', tip
    ) ORDER BY region_name), '[]'::jsonb) INTO out FROM public.regional_ingredient_hints;
    RETURN out;
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'region_key', region_key, 'region_name', region_name,
    'hints', hints, 'tip', tip
  )), '[]'::jsonb) INTO out
  FROM public.regional_ingredient_hints
  WHERE lower(region_key) = lower(btrim(p_region))
     OR lower(region_name) LIKE '%' || lower(btrim(p_region)) || '%';
  RETURN out;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_regional_ingredient_hints(text) TO anon, authenticated;

-- ── 3. Shared-edit conflict detection (grocery) ───────────────────────
DROP FUNCTION IF EXISTS public.save_my_grocery_list(jsonb, jsonb);
DROP FUNCTION IF EXISTS public.save_my_grocery_list(jsonb, jsonb, timestamptz);
CREATE FUNCTION public.save_my_grocery_list(
  p_list_data jsonb,
  p_checked jsonb DEFAULT '[]'::jsonb,
  p_client_updated_at timestamptz DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  h_id uuid;
  server_ts timestamptz;
  h_row public.households%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    SELECT * INTO h_row FROM public.households WHERE id = h_id;
    server_ts := h_row.grocery_updated_at;
    IF p_client_updated_at IS NOT NULL AND server_ts > p_client_updated_at THEN
      RETURN jsonb_build_object(
        'ok', false, 'conflict', true,
        'list_data', h_row.grocery_list_data,
        'checked', h_row.grocery_checked,
        'updated_at', server_ts,
        'household_name', h_row.name
      );
    END IF;
    UPDATE public.households SET
      grocery_list_data = p_list_data,
      grocery_checked = COALESCE(p_checked, '[]'::jsonb),
      grocery_updated_at = now()
    WHERE id = h_id
    RETURNING grocery_updated_at INTO server_ts;
    RETURN jsonb_build_object('ok', true, 'updated_at', server_ts);
  END IF;
  INSERT INTO public.grocery_lists (user_id, list_data, checked, updated_at)
  VALUES (auth.uid(), p_list_data, COALESCE(p_checked, '[]'::jsonb), now())
  ON CONFLICT (user_id) DO UPDATE SET
    list_data = EXCLUDED.list_data,
    checked = EXCLUDED.checked,
    updated_at = now()
  RETURNING updated_at INTO server_ts;
  RETURN jsonb_build_object('ok', true, 'updated_at', server_ts);
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_my_grocery_list(jsonb, jsonb, timestamptz) TO authenticated;

-- ── 4. Shared-edit conflict detection (pantry) ────────────────────────
DROP FUNCTION IF EXISTS public.save_my_pantry(jsonb);
DROP FUNCTION IF EXISTS public.save_my_pantry(jsonb, timestamptz);
CREATE FUNCTION public.save_my_pantry(
  p_items jsonb,
  p_client_updated_at timestamptz DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  h_id uuid;
  server_ts timestamptz;
  h_row public.households%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    SELECT * INTO h_row FROM public.households WHERE id = h_id;
    server_ts := h_row.pantry_updated_at;
    IF p_client_updated_at IS NOT NULL AND server_ts > p_client_updated_at THEN
      RETURN jsonb_build_object(
        'ok', false, 'conflict', true,
        'items', h_row.pantry_items,
        'updated_at', server_ts,
        'household_name', h_row.name
      );
    END IF;
    UPDATE public.households SET
      pantry_items = COALESCE(p_items, '[]'::jsonb),
      pantry_updated_at = now()
    WHERE id = h_id
    RETURNING pantry_updated_at INTO server_ts;
    RETURN jsonb_build_object('ok', true, 'updated_at', server_ts);
  END IF;
  INSERT INTO public.pantry (user_id, items, updated_at)
  VALUES (auth.uid(), COALESCE(p_items, '[]'::jsonb), now())
  ON CONFLICT (user_id) DO UPDATE SET items = EXCLUDED.items, updated_at = now()
  RETURNING updated_at INTO server_ts;
  RETURN jsonb_build_object('ok', true, 'updated_at', server_ts);
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_my_pantry(jsonb, timestamptz) TO authenticated;

-- ── 5. Shared-edit conflict detection (meal plan) ─────────────────────
DROP FUNCTION IF EXISTS public.save_my_meal_plan(text, jsonb);
DROP FUNCTION IF EXISTS public.save_my_meal_plan(text, jsonb, timestamptz);
CREATE OR REPLACE FUNCTION public.save_my_meal_plan(
  p_week_key text,
  p_plan_data jsonb,
  p_client_updated_at timestamptz DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  h_id uuid;
  server_ts timestamptz;
  h_name text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  h_id := public._my_household_id();
  IF h_id IS NOT NULL THEN
    SELECT h.name, COALESCE(hmp.updated_at, to_timestamp(0))
    INTO h_name, server_ts
    FROM public.households h
    LEFT JOIN public.household_meal_plans hmp
      ON hmp.household_id = h.id AND hmp.week_key = p_week_key
    WHERE h.id = h_id;
    IF p_client_updated_at IS NOT NULL AND server_ts > p_client_updated_at THEN
      RETURN jsonb_build_object(
        'ok', false, 'conflict', true,
        'plan_data', COALESCE((SELECT plan_data FROM household_meal_plans WHERE household_id = h_id AND week_key = p_week_key), '{}'::jsonb),
        'updated_at', server_ts,
        'household_name', h_name
      );
    END IF;
    INSERT INTO household_meal_plans (household_id, week_key, plan_data, updated_at)
    VALUES (h_id, p_week_key, COALESCE(p_plan_data, '{}'), now())
    ON CONFLICT (household_id, week_key)
    DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = now()
    RETURNING updated_at INTO server_ts;
    PERFORM public._sync_meal_plan_slots('household', h_id, p_week_key, COALESCE(p_plan_data, '{}'));
    RETURN jsonb_build_object('ok', true, 'updated_at', server_ts);
  END IF;
  INSERT INTO meal_plans (user_id, week_key, plan_data, updated_at)
  VALUES (auth.uid(), p_week_key, COALESCE(p_plan_data, '{}'), now())
  ON CONFLICT (user_id, week_key)
  DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = now()
  RETURNING updated_at INTO server_ts;
  PERFORM public._sync_meal_plan_slots('user', auth.uid(), p_week_key, COALESCE(p_plan_data, '{}'));
  RETURN jsonb_build_object('ok', true, 'updated_at', server_ts);
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_my_meal_plan(text, jsonb, timestamptz) TO authenticated;

-- ── 6. UM feature toggle: print premium layout gating (D4) ────────────
INSERT INTO public.site_features (key, enabled, name, description, sort_order)
VALUES (
  'print_premium_layouts',
  true,
  'Print Studio — premium layouts free',
  'When OFF, botanical/wedding/vintage etc. require paid tier. Soft-launch: keep ON.',
  96
)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description;
