-- =============================================================================
-- THE CULINARY JOURNAL — GARDEN v4 (varieties + climate-first + tomato cultivars)
-- Requires RUN-GARDEN-V3.sql (+ polish) already applied on Supabase.
-- Paste THE ENTIRE FILE in SQL Editor. Safe to re-run.
-- =============================================================================


-- ########## BEGIN: garden-v4-01-varieties.sql ##########
-- garden-v4-01-varieties.sql — cultivar layer (species + varieties + climate suitability + kitchen hinges)
-- Requires Garden v3. Additive only. Safe to re-run.

CREATE TABLE IF NOT EXISTS public.plant_varieties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  slug text NOT NULL,
  name text NOT NULL,
  lineage_type text CHECK (lineage_type IN ('heirloom','open_pollinated','hybrid','indigenous')),
  origin text,
  traits text,
  flesh_fruit text,
  yield_notes text,
  growing_notes text,
  availability text,
  sort_order smallint NOT NULL DEFAULT 0,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plant_id, slug)
);

DROP TRIGGER IF EXISTS plant_varieties_updated_at ON public.plant_varieties;
CREATE TRIGGER plant_varieties_updated_at
  BEFORE UPDATE ON public.plant_varieties
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.variety_climate_suitability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  variety_id uuid NOT NULL REFERENCES public.plant_varieties(id) ON DELETE CASCADE,
  climate_zone_id uuid NOT NULL REFERENCES public.climate_zones(id) ON DELETE CASCADE,
  suitability text NOT NULL DEFAULT 'recommended',
  climate_notes text,
  UNIQUE (variety_id, climate_zone_id)
);

-- Per-variety kitchen hinge (when cultivar maps to a distinct governed ingredient)
CREATE TABLE IF NOT EXISTS public.variety_ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  variety_id uuid NOT NULL REFERENCES public.plant_varieties(id) ON DELETE CASCADE,
  ingredient_id integer NOT NULL REFERENCES public.ingredients("ID") ON DELETE CASCADE,
  part text NOT NULL DEFAULT '',
  is_primary boolean NOT NULL DEFAULT true,
  notes text,
  UNIQUE (variety_id, ingredient_id, part)
);

-- Optional: track which cultivar a member is growing
ALTER TABLE public.user_plants
  ADD COLUMN IF NOT EXISTS variety_id uuid REFERENCES public.plant_varieties(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.garden_lineage_label(p_type text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_type
    WHEN 'heirloom' THEN 'Heirloom'
    WHEN 'open_pollinated' THEN 'Open-pollinated'
    WHEN 'hybrid' THEN 'Hybrid (F1)'
    WHEN 'indigenous' THEN 'Indigenous / regional'
    ELSE NULL
  END;
$$;

SELECT 'garden-v4-01-varieties ready' AS status;
-- ########## END: garden-v4-01-varieties.sql ##########

-- ########## BEGIN: garden-v4-02-climates-regions.sql ##########
-- garden-v4-02-climates-regions.sql — climate-first seed (Brisbane → humid-subtropical, Kerala → tropical-monsoon)

INSERT INTO public.climate_zones (slug, name) VALUES
  ('humid-subtropical', 'Humid subtropical'),
  ('tropical-monsoon', 'Tropical monsoon')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.regions (slug, name, climate_zone_id, is_active) VALUES
  ('in-kerala', 'Kerala / Thiruvalla',
   (SELECT id FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1), true),
  ('au-brisbane', 'Brisbane',
   (SELECT id FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1), true)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  climate_zone_id = EXCLUDED.climate_zone_id,
  is_active = EXCLUDED.is_active;

-- Map existing au-southeast to humid-subtropical if present
UPDATE public.regions SET climate_zone_id = (SELECT id FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1)
WHERE slug = 'au-southeast'
  AND climate_zone_id IS DISTINCT FROM (SELECT id FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1);

SELECT 'garden-v4-02-climates-regions ready' AS status;
-- ########## END: garden-v4-02-climates-regions.sql ##########

-- ########## BEGIN: garden-v4-02b-tomato-climate-extend.sql ##########
-- garden-v4-02b-tomato-climate-extend.sql — mirror warm-temperate care/calendar to humid-subtropical for tomato

INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
SELECT p.id, cz_new.id, cc.field_key, cc.core, cc.risk, cc.fix
FROM public.plants p
JOIN public.plant_climate_care cc ON cc.plant_id = p.id
JOIN public.climate_zones cz_old ON cz_old.id = cc.climate_zone_id AND cz_old.slug = 'warm-temperate'
JOIN public.climate_zones cz_new ON cz_new.slug = 'humid-subtropical'
WHERE p.slug = 'tomato'
ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
  core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
SELECT p.id, cz_new.id, pc.activity, pc.month_start, pc.month_end, pc.notes
FROM public.plants p
JOIN public.plant_calendar pc ON pc.plant_id = p.id
JOIN public.climate_zones cz_old ON cz_old.id = pc.climate_zone_id AND cz_old.slug = 'warm-temperate'
JOIN public.climate_zones cz_new ON cz_new.slug = 'humid-subtropical'
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.plant_calendar ex
    WHERE ex.plant_id = p.id AND ex.climate_zone_id = cz_new.id
      AND ex.activity = pc.activity AND ex.month_start = pc.month_start
  );

SELECT 'garden-v4-02b-tomato-climate-extend ready' AS status;
-- ########## END: garden-v4-02b-tomato-climate-extend.sql ##########

-- ########## BEGIN: garden-v4-03-user-climate.sql ##########
-- garden-v4-03-user-climate.sql — climate-first member preference (direct climate, region optional)

ALTER TABLE public.user_regions
  ADD COLUMN IF NOT EXISTS climate_zone_id uuid REFERENCES public.climate_zones(id) ON DELETE SET NULL;

-- region_id optional when climate set directly
ALTER TABLE public.user_regions ALTER COLUMN region_id DROP NOT NULL;

DROP FUNCTION IF EXISTS public.set_my_garden_climate(uuid);
CREATE OR REPLACE FUNCTION public.set_my_garden_climate(p_climate_zone_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.climate_zones WHERE id = p_climate_zone_id) THEN
    RAISE EXCEPTION 'climate_not_found';
  END IF;
  INSERT INTO public.user_regions (user_id, climate_zone_id, region_id)
  VALUES (auth.uid(), p_climate_zone_id, NULL)
  ON CONFLICT (user_id) DO UPDATE SET climate_zone_id = EXCLUDED.climate_zone_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_my_garden_climate(uuid) TO authenticated;

-- Resolve member climate: direct preference → region cascade
CREATE OR REPLACE FUNCTION public.garden_user_climate_id(p_user_id uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(ur.climate_zone_id, r.climate_zone_id)
  FROM public.user_regions ur
  LEFT JOIN public.regions r ON r.id = ur.region_id
  WHERE ur.user_id = p_user_id
  LIMIT 1;
$$;

SELECT 'garden-v4-03-user-climate ready' AS status;
-- ########## END: garden-v4-03-user-climate.sql ##########

-- ########## BEGIN: garden-v4-04-import-queue.sql ##########
-- garden-v4-04-import-queue.sql — staging for Variety Assessment docx ingestion

CREATE TABLE IF NOT EXISTS public.garden_import_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_path text NOT NULL,
  species_name text,
  species_slug text,
  climate_slug text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','parsed','staging','approved','failed')),
  variety_count integer NOT NULL DEFAULT 0,
  payload jsonb,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz
);

CREATE INDEX IF NOT EXISTS garden_import_queue_status_idx ON public.garden_import_queue (status, created_at DESC);

SELECT 'garden-v4-04-import-queue ready' AS status;
-- ########## END: garden-v4-04-import-queue.sql ##########

-- ########## BEGIN: garden-v4-05-rpcs.sql ##########
-- garden-v4-05-rpcs.sql — variety-aware public RPCs + climate-first seasonal engine

-- Member region/climate (direct climate support)
DROP FUNCTION IF EXISTS public.get_my_garden_region();
CREATE OR REPLACE FUNCTION public.get_my_garden_region()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE v json;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT json_build_object(
    'region_id', r.id,
    'region_name', r.name,
    'climate_zone_id', COALESCE(ur.climate_zone_id, r.climate_zone_id),
    'climate_zone', cz.name,
    'climate_slug', cz.slug
  ) INTO v
  FROM public.user_regions ur
  LEFT JOIN public.regions r ON r.id = ur.region_id
  LEFT JOIN public.climate_zones cz ON cz.id = COALESCE(ur.climate_zone_id, r.climate_zone_id)
  WHERE ur.user_id = auth.uid()
  LIMIT 1;
  RETURN v;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_garden_region() TO authenticated;

-- Plant detail with varieties (public: names + lineage labels; slugs for routing only)
DROP FUNCTION IF EXISTS public.get_plant_by_slug(text);
DROP FUNCTION IF EXISTS public.get_plant_by_slug(text, text);
CREATE OR REPLACE FUNCTION public.get_plant_by_slug(
  p_slug text,
  p_climate_slug text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_climate uuid;
  v json;
BEGIN
  SELECT id INTO v_id FROM public.plants WHERE slug = p_slug AND is_published = true LIMIT 1;
  IF v_id IS NULL THEN RETURN NULL; END IF;
  IF p_climate_slug IS NOT NULL AND p_climate_slug <> '' THEN
    SELECT id INTO v_climate FROM public.climate_zones WHERE slug = p_climate_slug LIMIT 1;
  END IF;

  SELECT json_build_object(
    'plant', json_build_object(
      'id', p.id, 'slug', p.slug,
      'common_name', p.common_name, 'botanical_name', p.botanical_name,
      'plant_family', p.plant_family, 'plant_type', p.plant_type,
      'variety_cultivar', p.variety_cultivar, 'origin', p.origin,
      'size_height', p.size_height, 'size_spread', p.size_spread,
      'care_summary', p.care_summary,
      'growth_rate', p.growth_rate, 'planting_windows', p.planting_windows,
      'pollination_type', p.pollination_type, 'flowering_season', p.flowering_season,
      'propagation_methods', p.propagation_methods, 'germination_time', p.germination_time,
      'time_to_harvest', p.time_to_harvest,
      'harvest_season', p.harvest_season, 'harvesting_method', p.harvesting_method,
      'yield_per_plant', p.yield_per_plant, 'storage_methods', p.storage_methods,
      'edible_parts', p.edible_parts, 'culinary_applications', p.culinary_applications,
      'toxic_parts', p.toxic_parts, 'wildlife_attraction', p.wildlife_attraction,
      'ease_rating', er.name, 'lifecycle', lc.name,
      'growth_habit', gh.name, 'garden_layer', gl.name
    ),
    'parts', COALESCE((
      SELECT json_agg(row_to_json(pp.*) ORDER BY pp.part)
      FROM public.plant_parts pp WHERE pp.plant_id = v_id
    ), '[]'::json),
    'calendar', COALESCE((
      SELECT json_agg(json_build_object(
        'activity', pc.activity, 'month_start', pc.month_start, 'month_end', pc.month_end,
        'notes', pc.notes, 'climate_zone', cz.name
      ) ORDER BY pc.month_start)
      FROM public.plant_calendar pc
      LEFT JOIN public.climate_zones cz ON cz.id = pc.climate_zone_id
      WHERE pc.plant_id = v_id
        AND (v_climate IS NULL OR pc.climate_zone_id IS NULL OR pc.climate_zone_id = v_climate)
    ), '[]'::json),
    'climate_care', COALESCE((
      SELECT json_agg(json_build_object(
        'field_key', cc.field_key, 'core', cc.core, 'risk', cc.risk, 'fix', cc.fix,
        'climate_zone', cz.name
      ) ORDER BY cc.field_key)
      FROM public.plant_climate_care cc
      LEFT JOIN public.climate_zones cz ON cz.id = cc.climate_zone_id
      WHERE cc.plant_id = v_id
        AND (v_climate IS NULL OR cc.climate_zone_id IS NULL OR cc.climate_zone_id = v_climate)
    ), '[]'::json),
    'varieties', COALESCE((
      SELECT json_agg(json_build_object(
        'id', pv.id,
        'slug', pv.slug,
        'name', pv.name,
        'lineage_label', public.garden_lineage_label(pv.lineage_type),
        'origin', pv.origin,
        'traits', pv.traits,
        'flesh_fruit', pv.flesh_fruit,
        'yield_notes', pv.yield_notes,
        'growing_notes', pv.growing_notes,
        'availability', pv.availability,
        'climate_notes', vcs.climate_notes,
        'ingredient_name', COALESCE(vi_ing."Ingredient Name", sp_ing."Ingredient Name"),
        'library_slug', COALESCE(vi_lp.slug, sp_lp.slug)
      ) ORDER BY pv.sort_order, pv.name)
      FROM public.plant_varieties pv
      INNER JOIN public.variety_climate_suitability vcs ON vcs.variety_id = pv.id
        AND (v_climate IS NULL OR vcs.climate_zone_id = v_climate)
      LEFT JOIN public.variety_ingredients vi ON vi.variety_id = pv.id AND vi.is_primary = true
      LEFT JOIN public.ingredients vi_ing ON vi_ing."ID" = vi.ingredient_id
      LEFT JOIN public.library_profiles vi_lp
        ON vi_lp.profile_type = 'ingredient' AND vi_lp.governed_ingredient_id = vi.ingredient_id
      LEFT JOIN public.plant_ingredients pi ON pi.plant_id = v_id AND pi.is_primary = true
      LEFT JOIN public.ingredients sp_ing ON sp_ing."ID" = pi.ingredient_id
      LEFT JOIN public.library_profiles sp_lp
        ON sp_lp.profile_type = 'ingredient' AND sp_lp.governed_ingredient_id = pi.ingredient_id
      WHERE pv.plant_id = v_id AND pv.is_published = true
    ), '[]'::json),
    'ingredients', COALESCE((
      SELECT json_agg(json_build_object(
        'ingredient_id', pi.ingredient_id,
        'ingredient_name', i."Ingredient Name",
        'library_slug', lp.slug,
        'part', pi.part,
        'is_primary', pi.is_primary
      ))
      FROM public.plant_ingredients pi
      JOIN public.ingredients i ON i."ID" = pi.ingredient_id
      LEFT JOIN public.library_profiles lp
        ON lp.profile_type = 'ingredient' AND lp.governed_ingredient_id = pi.ingredient_id
      WHERE pi.plant_id = v_id
    ), '[]'::json),
    'organisms', COALESCE((
      SELECT json_agg(json_build_object(
        'name', o.name, 'scientific_name', o.scientific_name,
        'kind', o.kind, 'relationship', po.relationship, 'notes', po.notes
      ))
      FROM public.plant_organisms po
      JOIN public.organisms o ON o.id = po.organism_id
      WHERE po.plant_id = v_id
    ), '[]'::json),
    'lessons', COALESCE((
      SELECT json_agg(json_build_object(
        'slug', l.slug, 'title', l.title, 'body', l.body, 'difficulty', l.difficulty
      ))
      FROM public.lesson_links ll
      JOIN public.lessons l ON l.id = ll.lesson_id AND l.is_published = true
      WHERE ll.entity_type = 'plant' AND ll.entity_id = v_id
    ), '[]'::json),
    'companions', COALESCE((
      SELECT json_agg(json_build_object(
        'relationship', c.relationship,
        'reason', c.reason,
        'other_slug', op.slug,
        'other_name', op.common_name
      ))
      FROM public.plant_companions c
      JOIN public.plants op ON op.id = c.other_plant_id
      WHERE c.plant_id = v_id
    ), '[]'::json),
    'safety_flags', COALESCE((
      SELECT json_agg(row_to_json(sf.*))
      FROM public.safety_flags sf
      WHERE sf.entity_type = 'plant' AND sf.entity_id = v_id
    ), '[]'::json)
  ) INTO v
  FROM public.plants p
  LEFT JOIN public.ease_ratings er ON er.id = p.ease_rating_id
  LEFT JOIN public.lifecycles lc ON lc.id = p.lifecycle_id
  LEFT JOIN public.growth_habits gh ON gh.id = p.growth_habit_id
  LEFT JOIN public.garden_layers gl ON gl.id = p.garden_layer_id
  WHERE p.id = v_id;
  RETURN v;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_plant_by_slug(text, text) TO anon, authenticated;

-- Published plants list with variety counts
DROP FUNCTION IF EXISTS public.get_published_plants(text, integer, integer);
CREATE OR REPLACE FUNCTION public.get_published_plants(
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
BEGIN
  p_limit := GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));
  RETURN QUERY
    SELECT json_build_object(
      'slug', p.slug,
      'common_name', p.common_name,
      'botanical_name', p.botanical_name,
      'care_summary', p.care_summary,
      'plant_family', p.plant_family,
      'plant_type', p.plant_type,
      'harvest_season', p.harvest_season,
      'ease_rating', er.name,
      'lifecycle', lc.name,
      'growth_habit', gh.name,
      'high_level_category', ch.name,
      'variety_count', (SELECT count(*)::int FROM public.plant_varieties pv WHERE pv.plant_id = p.id AND pv.is_published = true)
    )
    FROM public.plants p
    LEFT JOIN public.ease_ratings er ON er.id = p.ease_rating_id
    LEFT JOIN public.lifecycles lc ON lc.id = p.lifecycle_id
    LEFT JOIN public.growth_habits gh ON gh.id = p.growth_habit_id
    LEFT JOIN public.cat_high_level ch ON ch.id = p.high_level_category_id
    WHERE p.is_published = true
      AND (p_search IS NULL OR p_search = ''
           OR p.common_name ILIKE '%' || p_search || '%'
           OR p.botanical_name ILIKE '%' || p_search || '%')
    ORDER BY p.common_name
    LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_published_plants(text, integer, integer) TO anon, authenticated;

-- Seasonal engine uses direct climate preference
DROP FUNCTION IF EXISTS public.garden_what_now(smallint);
CREATE OR REPLACE FUNCTION public.garden_what_now(p_month smallint DEFAULT NULL)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE
  v_month smallint;
  v_climate uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v_month := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::smallint);
  v_climate := public.garden_user_climate_id(auth.uid());
  RETURN QUERY
    SELECT json_build_object(
      'plant_slug', p.slug,
      'plant_name', p.common_name,
      'variety_name', pv.name,
      'activity', pc.activity,
      'month_start', pc.month_start,
      'month_end', pc.month_end,
      'notes', pc.notes,
      'user_status', up.status,
      'bed_label', up.bed_label
    )
    FROM public.user_plants up
    JOIN public.plants p ON p.id = up.plant_id AND p.is_published = true
    LEFT JOIN public.plant_varieties pv ON pv.id = up.variety_id
    JOIN public.plant_calendar pc ON pc.plant_id = p.id
    WHERE up.user_id = auth.uid()
      AND up.status IN ('planned','growing','harvesting')
      AND public.garden_month_in_range(v_month, pc.month_start, pc.month_end)
      AND (pc.climate_zone_id IS NULL OR v_climate IS NULL OR pc.climate_zone_id = v_climate)
    ORDER BY pc.activity, p.common_name;
END;
$$;
GRANT EXECUTE ON FUNCTION public.garden_what_now(smallint) TO authenticated;

DROP FUNCTION IF EXISTS public.garden_what_next(smallint);
CREATE OR REPLACE FUNCTION public.garden_what_next(p_month smallint DEFAULT NULL)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE
  v_month smallint;
  v_climate uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v_month := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::smallint);
  v_climate := public.garden_user_climate_id(auth.uid());
  RETURN QUERY
    SELECT json_build_object(
      'plant_slug', p.slug,
      'plant_name', p.common_name,
      'variety_name', pv.name,
      'activity', pc.activity,
      'month_start', pc.month_start,
      'month_end', pc.month_end,
      'notes', pc.notes,
      'months_away', (
        CASE WHEN pc.month_start >= v_month THEN pc.month_start - v_month
             ELSE (12 - v_month) + pc.month_start END
      )
    )
    FROM public.user_plants up
    JOIN public.plants p ON p.id = up.plant_id AND p.is_published = true
    LEFT JOIN public.plant_varieties pv ON pv.id = up.variety_id
    JOIN public.plant_calendar pc ON pc.plant_id = p.id
    WHERE up.user_id = auth.uid()
      AND up.status IN ('planned','growing','harvesting')
      AND NOT public.garden_month_in_range(v_month, pc.month_start, pc.month_end)
      AND (pc.climate_zone_id IS NULL OR v_climate IS NULL OR pc.climate_zone_id = v_climate)
    ORDER BY (
      CASE WHEN pc.month_start >= v_month THEN pc.month_start - v_month
           ELSE (12 - v_month) + pc.month_start END
    ) ASC, p.common_name
    LIMIT 6;
END;
$$;
GRANT EXECUTE ON FUNCTION public.garden_what_next(smallint) TO authenticated;

DROP FUNCTION IF EXISTS public.get_my_garden_plants();
CREATE OR REPLACE FUNCTION public.get_my_garden_plants()
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT json_build_object(
      'id', up.id,
      'status', up.status,
      'planted_at', up.planted_at,
      'bed_label', up.bed_label,
      'notes', up.notes,
      'plant_slug', p.slug,
      'plant_name', p.common_name,
      'variety_slug', pv.slug,
      'variety_name', pv.name,
      'lineage_label', public.garden_lineage_label(pv.lineage_type),
      'care_summary', p.care_summary
    )
    FROM public.user_plants up
    JOIN public.plants p ON p.id = up.plant_id
    LEFT JOIN public.plant_varieties pv ON pv.id = up.variety_id
    WHERE up.user_id = auth.uid()
    ORDER BY up.updated_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_garden_plants() TO authenticated;

DROP FUNCTION IF EXISTS public.upsert_my_garden_plant(uuid, text, date, text, text);
DROP FUNCTION IF EXISTS public.upsert_my_garden_plant(uuid, text, date, text, text, uuid);
CREATE OR REPLACE FUNCTION public.upsert_my_garden_plant(
  p_plant_id uuid,
  p_status text DEFAULT 'planned',
  p_planted_at date DEFAULT NULL,
  p_bed_label text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_variety_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.plants WHERE id = p_plant_id AND is_published = true) THEN
    RAISE EXCEPTION 'plant_not_found';
  END IF;
  IF p_variety_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.plant_varieties WHERE id = p_variety_id AND plant_id = p_plant_id AND is_published = true
  ) THEN
    RAISE EXCEPTION 'variety_not_found';
  END IF;
  INSERT INTO public.user_plants (user_id, plant_id, variety_id, status, planted_at, bed_label, notes)
  VALUES (auth.uid(), p_plant_id, p_variety_id, COALESCE(p_status, 'planned'), p_planted_at, p_bed_label, p_notes)
  ON CONFLICT (user_id, plant_id) DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    SELECT id INTO v_id FROM public.user_plants
    WHERE user_id = auth.uid() AND plant_id = p_plant_id LIMIT 1;
    UPDATE public.user_plants SET
      variety_id = COALESCE(p_variety_id, variety_id),
      status = COALESCE(p_status, status),
      planted_at = COALESCE(p_planted_at, planted_at),
      bed_label = COALESCE(p_bed_label, bed_label),
      notes = COALESCE(p_notes, notes),
      updated_at = now()
    WHERE id = v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_my_garden_plant(uuid, text, date, text, text, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'garden-v4-05-rpcs ready' AS status;
-- ########## END: garden-v4-05-rpcs.sql ##########

-- ########## BEGIN: garden-v4-06-rls.sql ##########
-- garden-v4-06-rls.sql — RLS for variety layer + import queue

ALTER TABLE public.plant_varieties ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "garden varieties published read" ON public.plant_varieties;
CREATE POLICY "garden varieties published read" ON public.plant_varieties
  FOR SELECT TO anon, authenticated USING (is_published = true);
DROP POLICY IF EXISTS "garden varieties admin" ON public.plant_varieties;
CREATE POLICY "garden varieties admin" ON public.plant_varieties
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON public.plant_varieties TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.plant_varieties TO authenticated;

ALTER TABLE public.variety_climate_suitability ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "variety climate read" ON public.variety_climate_suitability;
CREATE POLICY "variety climate read" ON public.variety_climate_suitability
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "variety climate admin" ON public.variety_climate_suitability;
CREATE POLICY "variety climate admin" ON public.variety_climate_suitability
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON public.variety_climate_suitability TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.variety_climate_suitability TO authenticated;

ALTER TABLE public.variety_ingredients ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "variety ingredients read" ON public.variety_ingredients;
CREATE POLICY "variety ingredients read" ON public.variety_ingredients
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "variety ingredients admin" ON public.variety_ingredients;
CREATE POLICY "variety ingredients admin" ON public.variety_ingredients
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON public.variety_ingredients TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.variety_ingredients TO authenticated;

ALTER TABLE public.garden_import_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "garden import admin" ON public.garden_import_queue;
CREATE POLICY "garden import admin" ON public.garden_import_queue
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.garden_import_queue TO authenticated;

SELECT 'garden-v4-06-rls ready' AS status;
-- ########## END: garden-v4-06-rls.sql ##########

-- ########## BEGIN: garden-v4-07-seed-tomato-varieties.sql ##########
-- garden-v4-07-seed-tomato-varieties.sql — auto-generated from _extracted_tomato.txt
-- Safe to re-run. Publishes cultivars for humid-subtropical + tropical-monsoon.

DO $$
DECLARE
  v_plant uuid;
  v_climate uuid;
  v_var uuid;
  v_ing integer;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'tomato' LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'tomato plant missing — run RUN-GARDEN-V3.sql first'; END IF;
  SELECT "ID" INTO v_ing FROM public.ingredients WHERE lower("Ingredient Name") LIKE '%tomato%' ORDER BY "ID" LIMIT 1;

  -- Grosse Lisse (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'grosse-lisse', 'Grosse Lisse', 'open_pollinated', 'Australia, 1970s standard', 'Indeterminate 2-3.5m, medium-large 6-10cm oblate', 'Smooth, firm, tangy sun-ripened', '80 days from seedlings, 15-20 tons/ha', 'Brisbane: Excellent subtropical. Sets fruit hot conditions. Improved disease resistance. Australian standard 50+ years.', 'Widely available: Qld nurseries, Bunnings, Diggers, Eden', 0, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'grosse-lisse');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'grosse-lisse' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent subtropical. Sets fruit hot conditions. Improved disease resistance. Australian standard 50+ years.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Grosse Lisse')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Tommy Toe (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'tommy-toe', 'Tommy Toe', 'heirloom', 'USA Ozark, early 1900s', 'Indeterminate 2.2-2.7m, cherry 2-3cm', 'Sweet, rich, firm, superior taste', 'Mid-late, 10kg+/plant, trusses 7-9', 'Brisbane: Outstanding subtropical, humidity adapted, disease tolerant. Diggers winner since 1993. Must-have for Brisbane.', 'Qld nurseries, Diggers, Eden, Green Harvest', 1, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tommy-toe');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tommy-toe' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Outstanding subtropical, humidity adapted, disease tolerant. Diggers winner since 1993. Must-have for Brisbane.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Tommy Toe')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Green Zebra (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'green-zebra', 'Green Zebra', 'heirloom', 'USA, Tom Wagner 1983', 'Indeterminate 1.5-2m, round 5-7cm striped', 'Rich, creamy, tangy-sweet, yellow-green ripe', 'Mid-season, excellent winter cropper', 'Brisbane: Good winter cropper, tolerates cooler temps. Distinctive appearance, good disease resistance humidity.', 'Specialty nurseries, Diggers, Seed Collection', 2, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'green-zebra');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'green-zebra' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Good winter cropper, tolerates cooler temps. Distinctive appearance, good disease resistance humidity.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Green Zebra')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Tigerella (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'tigerella', 'Tigerella', 'heirloom', 'UK 1970s', 'Indeterminate, medium red-orange stripes', 'Sweet-tangy balanced, firm, colorful', 'Early-mid, productive', 'Brisbane: Performs well subtropical. Good disease resistance. Attractive striped. Reliable garden variety.', 'Qld nurseries, online suppliers', 3, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tigerella');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tigerella' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Performs well subtropical. Good disease resistance. Attractive striped. Reliable garden variety.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Tigerella')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Roma / Mini Roma (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'roma-mini-roma', 'Roma / Mini Roma', 'open_pollinated', 'Italy, traditional paste', 'Determinate bush, plum, thick walls', 'Meaty, low moisture, mild, few seeds', 'Heavy yields, ripens together', 'Brisbane: Excellent subtropical, heat/humidity tolerant. Ideal sauces, canning. Mini Roma compact. Good disease resistance.', 'Very common - all Qld nurseries, Bunnings', 4, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'roma-mini-roma');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'roma-mini-roma' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent subtropical, heat/humidity tolerant. Ideal sauces, canning. Mini Roma compact. Good disease resistance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Roma / Mini Roma')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Black Russian (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'black-russian', 'Black Russian', 'heirloom', 'Russia/Ukraine', 'Indeterminate 1.5-2m, almost black, 4-6cm', 'Dark, sweet, pulpy plum-like, rich', 'Mid-season, moderate', 'Brisbane: Grows well but fruit fly prone - exclusion netting essential. Distinctive dark, excellent flavor. Best netted humid summers.', 'Specialty, Diggers, heirloom suppliers', 5, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-russian');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-russian' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Grows well but fruit fly prone - exclusion netting essential. Distinctive dark, excellent flavor. Best netted humid summers.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Black Russian')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Mortgage Lifter (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'mortgage-lifter', 'Mortgage Lifter', 'heirloom', 'USA, WV 1930s', 'Indeterminate, beefsteak to 500g', 'Pink-red, meaty, sweet low acidity', 'Mid-late, large need support', 'Brisbane: Personal best performer. Strong staking required. Good subtropical. Excellent slicing.', 'Heirloom suppliers, Diggers, Eden', 6, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'mortgage-lifter');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'mortgage-lifter' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Personal best performer. Strong staking required. Good subtropical. Excellent slicing.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Mortgage Lifter')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Black Cherry (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'black-cherry', 'Black Cherry', 'heirloom', 'USA Florida, V.Sapp modern', 'Indeterminate, cherry 3cm, purple-black', 'Rich, sweet, smoky, complex', '10-12 weeks, prolific clusters', 'Brisbane: Bred for warm humid Florida - perfect! Excellent disease/heat tolerance. Vigorous, productive. Sow Mar-Sep.', 'Succeed Heirlooms, Seed Collection', 7, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-cherry');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-cherry' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Bred for warm humid Florida - perfect! Excellent disease/heat tolerance. Vigorous, productive. Sow Mar-Sep.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Black Cherry')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Apollo Improved (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'apollo-improved', 'Apollo Improved', 'hybrid', 'Australia, F1', 'Indeterminate, early, firm', 'Mild, low acid', 'Sets at 10°C, early producer', 'Brisbane: Excellent mild winters. Improved bacterial wilt, nematode resistance. Firmer fruit. Good all-season subtropical.', 'Qld nurseries, commercial suppliers', 8, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'apollo-improved');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'apollo-improved' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent mild winters. Improved bacterial wilt, nematode resistance. Firmer fruit. Good all-season subtropical.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Apollo Improved')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Beefsteak (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'beefsteak', 'Beefsteak', 'open_pollinated', 'Traditional large', 'Open-pollinated, 1-1.5m, 10-12cm oblate', 'Meaty, firm, rich, classic slicing', 'Mid-season, sturdy, moderate', 'Brisbane: Performs well with support. Heavy fruits need staking. Good heat. Excellent fresh, sandwiches.', 'Common Qld nurseries', 9, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'beefsteak');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'beefsteak' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Performs well with support. Heavy fruits need staking. Good heat. Excellent fresh, sandwiches.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Beefsteak')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Scorpio (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'scorpio', 'Scorpio', 'indigenous', 'Queensland, bred for subtropical/tropical', 'Indeterminate, standard red', 'Tasty, firm, good quality', '10-12 weeks, good yields', 'Brisbane: BRED FOR QUEENSLAND! Tolerates humid subtropical/tropical. Resistant bacterial/fusarium wilts. Local adaptation excellent.', 'Succeed Heirlooms, Qld suppliers', 10, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scorpio');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scorpio' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: BRED FOR QUEENSLAND! Tolerates humid subtropical/tropical. Resistant bacterial/fusarium wilts. Local adaptation excellent.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Scorpio')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Scoresby Dwarf (KY1) (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'scoresby-dwarf-ky1', 'Scoresby Dwarf (KY1)', 'heirloom', 'Australian heirloom', 'Determinate, compact, round 5cm', 'Rich, ideal sauces', 'Very productive, good disease resistance', 'Brisbane: Australian heritage, locally adapted. Compact for small gardens/containers. Good disease resistance humidity. Excellent sauces.', 'Succeed Heirlooms Australia', 11, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scoresby-dwarf-ky1');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'scoresby-dwarf-ky1' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Australian heritage, locally adapted. Compact for small gardens/containers. Good disease resistance humidity. Excellent sauces.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Scoresby Dwarf (KY1)')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Cherokee Purple (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'cherokee-purple', 'Cherokee Purple', 'heirloom', 'USA Cherokee, pre-1890', 'Indeterminate, 10-12oz, mahogany green shoulders', 'Classic old-time, sweet rich', 'Mid-season, moderate large', 'Brisbane: Loves wet heat - perfect humid summers! Not dry heat. Excellent disease resistance. Solid production. Rich complex. Green shoulders normal.', 'Heirloom suppliers, Diggers, widely available', 12, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'cherokee-purple');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'cherokee-purple' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Loves wet heat - perfect humid summers! Not dry heat. Excellent disease resistance. Solid production. Rich complex. Green shoulders normal.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Cherokee Purple')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- San Marzano (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'san-marzano', 'San Marzano', 'heirloom', 'Italy, traditional paste', 'Indeterminate, plum, thick-walled', 'Classic Italian, ideal sauces, meaty', 'Very productive long hot, excellent disease', 'Brisbane: Top heat-tolerant performer. Incredibly productive long hot seasons. Excellent disease resistance humidity. Perfect canning, roasting, sauces.', 'Common - most Qld nurseries, Italian', 13, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'san-marzano');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'san-marzano' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Top heat-tolerant performer. Incredibly productive long hot seasons. Excellent disease resistance humidity. Perfect canning, roasting, sauces.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: San Marzano')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Chadwick Cherry / Camp Joy (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'chadwick-cherry-camp-joy', 'Chadwick Cherry / Camp Joy', 'heirloom', 'Extreme heat-tolerant', 'Cherry, extreme heat tolerance', 'Sets fruit to 45°C (115°F)', 'Continues producing extreme heat', 'Brisbane: Excellent hottest summer (Jan-Feb). Rare ability set fruit extreme temps. Good backup heat waves.', 'Specialty heat-tolerant suppliers', 14, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'chadwick-cherry-camp-joy');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'chadwick-cherry-camp-joy' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent hottest summer (Jan-Feb). Rare ability set fruit extreme temps. Good backup heat waves.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Chadwick Cherry / Camp Joy')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Bite Size (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'bite-size', 'Bite Size', 'hybrid', 'F1 hybrid', 'Indeterminate 2.2-2.7m, cherry 3cm', 'Sweet, firm, thick-skinned', '77-84 days, 20-50 per truss', 'Brisbane: Disease resistance package. Train to three leaders. Vigorous long season.', 'Seedlings, commercial nurseries', 15, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bite-size');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bite-size' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Disease resistance package. Train to three leaders. Vigorous long season.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Bite Size')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Sun Gold (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'sun-gold', 'Sun Gold', 'hybrid', 'Hybrid', 'Indeterminate 2m, golden cherry 1.5-2cm', 'Extremely sweet, bright golden', '100+ per truss, mid-late', 'Brisbane: Popular subtropical. Very sweet, children love. Prolific warm season. Good humidity.', 'Common - Qld nurseries, Bunnings', 16, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sun-gold');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sun-gold' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Popular subtropical. Very sweet, children love. Prolific warm season. Good humidity.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Sun Gold')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Sugarlump Cherry (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'sugarlump-cherry', 'Sugarlump Cherry', 'open_pollinated', 'Heritage', 'Cherry ombre color, large trusses', 'Sweet, colorful, attractive', 'Prolific, heavy trusses', 'Brisbane: Extensively tested excellent autumn. One of best for Brisbane. Good subtropical. Attractive ombre.', 'Love of Dirt (Brisbane), specialty', 17, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sugarlump-cherry');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'sugarlump-cherry' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Extensively tested excellent autumn. One of best for Brisbane. Good subtropical. Attractive ombre.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Sugarlump Cherry')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Thai Pink Egg (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'thai-pink-egg', 'Thai Pink Egg', 'heirloom', 'Thailand, Asian', 'Egg-shaped, white to rich pink', 'Distinctive pink, unique shape', 'Good warm climates', 'Brisbane: Asian tropical origin excellent subtropical. Heat/humidity adapted. Unique appearance. Good warm humid performance.', 'Succeed Heirlooms, Asian variety', 18, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thai-pink-egg');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thai-pink-egg' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Asian tropical origin excellent subtropical. Heat/humidity adapted. Unique appearance. Good warm humid performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Thai Pink Egg')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Amish Paste (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'amish-paste', 'Amish Paste', 'heirloom', 'USA Amish, pre-1900', 'Indeterminate, large paste plum', 'Meaty, thick-walled, few seeds', '12-14 weeks, heavy producer', 'Brisbane: One of best for sauces. Performs subtropical with disease management. Heat tolerant. Excellent cooking, canning.', 'Succeed Heirlooms, heirloom suppliers', 19, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'amish-paste');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'amish-paste' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: One of best for sauces. Performs subtropical with disease management. Heat tolerant. Excellent cooking, canning.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Amish Paste')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Pink Brandywine (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pink-brandywine', 'Pink Brandywine', 'heirloom', 'USA, Brandywine heat strain', 'Indeterminate, large to 2 pounds', 'Creamy, rich, perfect balance, pink', 'Large, moderate, long season', 'Brisbane: Better heat tolerance. Needs consistent watering, partial shade hottest months. Continues setting fruit heat. Best heat-tolerant heirloom flavor.', 'Heirloom suppliers, heat-tolerant specialists', 20, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pink-brandywine');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pink-brandywine' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Better heat tolerance. Needs consistent watering, partial shade hottest months. Continues setting fruit heat. Best heat-tolerant heirloom flavor.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pink Brandywine')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Pruden's Purple (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pruden-s-purple', 'Pruden''s Purple', 'heirloom', 'USA, potato-leaf', 'Early maturity, large smooth pink', 'Rich, tangy, firm, pink', 'Early, good before peak heat', 'Brisbane: Early maturity ideal - harvest before intense heat. Lower cracking humidity. Solid disease. Good autumn for spring harvest.', 'Heirloom suppliers, early-season', 21, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pruden-s-purple');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pruden-s-purple' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Early maturity ideal - harvest before intense heat. Lower cracking humidity. Solid disease. Good autumn for spring harvest.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pruden''s Purple')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Black Krim (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'black-krim', 'Black Krim', 'heirloom', 'Crimea, Ukraine', 'Indeterminate, beefsteak, dark mahogany', 'Slightly salty, rich, dark', 'Mid-late, good large', 'Brisbane: Performs well subtropical. Attractive dark. Rich complex. Good heat. Needs netting birds/fruit fly humidity.', 'Common heirloom - Diggers, most suppliers', 22, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-krim');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'black-krim' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Performs well subtropical. Attractive dark. Rich complex. Good heat. Needs netting birds/fruit fly humidity.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Black Krim')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Costoluto Genovese (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'costoluto-genovese', 'Costoluto Genovese', 'heirloom', 'Italy Genoa, traditional', 'Highly ribbed/fluted, indeterminate', 'Rich, intense, meaty', 'Good yields, mid-season', 'Brisbane: Italian warm climates similar Brisbane. Distinctive ribbed attractive. Excellent fresh/cooking. Good subtropical.', 'Italian variety specialists, heirloom', 23, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'costoluto-genovese');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'costoluto-genovese' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Italian warm climates similar Brisbane. Distinctive ribbed attractive. Excellent fresh/cooking. Good subtropical.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Costoluto Genovese')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Gardener's Delight (humid-subtropical)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'gardener-s-delight', 'Gardener''s Delight', 'heirloom', 'German, Sugar Lump', 'Indeterminate, sweet cherry', 'Exceptional sweetness, balanced', 'Very prolific, long harvesting', 'Brisbane: Excellent subtropical. Long harvesting extended season. Sweet family favorite. Reliable producer.', 'Common heirloom - widely available', 24, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'gardener-s-delight');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'gardener-s-delight' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Brisbane: Excellent subtropical. Long harvesting extended season. Sweet family favorite. Reliable producer.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Gardener''s Delight')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Pusa Ruby (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-ruby', 'Pusa Ruby', 'open_pollinated', 'IARI Delhi, widely grown', 'Semi-determinate, round, thick glossy skin, yellow stem end', 'Deep red, firm, balanced sugar-acid', '25-32 tons/ha, 90-100 days transplanting', 'Kerala: Highly popular, most widely grown India. Adaptable to climatic changes and soil types. Good pest resistance, thrives extreme conditions. Suitable spring-summer, autumn-winter. Both table and processing.', 'Widely available all Kerala nurseries, IARI', 0, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-ruby');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-ruby' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Highly popular, most widely grown India. Adaptable to climatic changes and soil types. Good pest resistance, thrives extreme conditions. Suitable spring-summer, autumn-winter. Both table and processing.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Ruby')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Rakshak (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-rakshak', 'Arka Rakshak', 'hybrid', 'IIHR Bangalore', 'Indeterminate, disease-resistant', 'Round, firm, good quality', '19 kg per plant, excellent yields', 'Kerala: HIGH-YIELDING &amp; DISEASE-RESISTANT. Crossing high-yielding F1. Resistant to ToLCV, bacterial wilt, early blight. Specifically developed for South India. Excellent tropical monsoon performance.', 'Kerala nurseries, IIHR, Indian Agricultural suppliers', 1, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-rakshak');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-rakshak' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: HIGH-YIELDING &amp; DISEASE-RESISTANT. Crossing high-yielding F1. Resistant to ToLCV, bacterial wilt, early blight. Specifically developed for South India. Excellent tropical monsoon performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Rakshak')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Abhijith (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-abhijith', 'Arka Abhijith', 'hybrid', 'IIHR Bangalore, F1 hybrid', 'Medium plant, bright red, 65-70g fruits', 'Good taste, suitable fresh and processing', '65 tons/ha in 140 days', 'Kerala: High-yielding for fresh market. Developed by IIHR specifically for Indian conditions. Good disease resistance. Performs well tropical monsoon.', 'Kerala nurseries, IIHR Bangalore', 2, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-abhijith');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-abhijith' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding for fresh market. Developed by IIHR specifically for Indian conditions. Good disease resistance. Performs well tropical monsoon.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Abhijith')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Samrat (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-samrat', 'Arka Samrat', 'hybrid', 'IIHR Bangalore', 'Determinate, uniform firm fruits', 'Rich taste, texture ideal for ketchup/puree', 'Good yields', 'Kerala: Popular for making ketchup and puree. Determinate - all fruit ripens together for processing. Good tropical adaptation. Uniform quality.', 'Kerala nurseries, IIHR', 3, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-samrat');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-samrat' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Popular for making ketchup and puree. Determinate - all fruit ripens together for processing. Good tropical adaptation. Uniform quality.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Samrat')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
  -- Arka Saurabh (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-saurabh', 'Arka Saurabh', 'hybrid', 'IIHR Bangalore hybrid', 'High-yielding, medium-sized juicy', 'Juicy, good quality', 'Adaptable to various climates', 'Kerala: High-yielding hybrid. Medium-sized juicy fruits. Preferred for adaptability to various climatic conditio', '', 4, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-saurabh');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-saurabh' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding hybrid. Medium-sized juicy fruits. Preferred for adaptability to various climatic conditio')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Saurabh')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;
END $$;

INSERT INTO public.garden_import_queue (source_path, species_name, species_slug, climate_slug, status, variety_count, payload)
VALUES ('brainstorm-inbox/_extracted_tomato.txt', 'Tomato', 'tomato', 'multi', 'approved', 30,
 '{"generated": true, "variety_count": 30}'::jsonb)
;

SELECT 'garden-v4-07-seed-tomato-varieties ready — 30 varieties' AS status;
-- ########## END: garden-v4-07-seed-tomato-varieties.sql ##########
