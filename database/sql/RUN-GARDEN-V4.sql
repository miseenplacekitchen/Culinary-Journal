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

-- ########## BEGIN: garden-v4-02c-tomato-monsoon-extend.sql ##########
-- garden-v4-02c-tomato-monsoon-extend.sql — mirror warm-temperate care/calendar to tropical-monsoon for tomato

INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
SELECT p.id, cz_new.id, cc.field_key, cc.core, cc.risk, cc.fix
FROM public.plants p
JOIN public.plant_climate_care cc ON cc.plant_id = p.id
JOIN public.climate_zones cz_old ON cz_old.id = cc.climate_zone_id AND cz_old.slug = 'warm-temperate'
JOIN public.climate_zones cz_new ON cz_new.slug = 'tropical-monsoon'
WHERE p.slug = 'tomato'
ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
  core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
SELECT p.id, cz_new.id, pc.activity, pc.month_start, pc.month_end,
  CASE WHEN pc.notes IS NULL OR pc.notes = '' THEN 'Kerala/monsoon timing — adjust for local sow Sep, transplant Oct.'
       ELSE pc.notes || ' (Kerala/monsoon — sow Sep, transplant Oct.)' END
FROM public.plants p
JOIN public.plant_calendar pc ON pc.plant_id = p.id
JOIN public.climate_zones cz_old ON cz_old.id = pc.climate_zone_id AND cz_old.slug = 'warm-temperate'
JOIN public.climate_zones cz_new ON cz_new.slug = 'tropical-monsoon'
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.plant_calendar ex
    WHERE ex.plant_id = p.id AND ex.climate_zone_id = cz_new.id
      AND ex.activity = pc.activity AND ex.month_start = pc.month_start
  );

SELECT 'garden-v4-02c-tomato-monsoon-extend ready' AS status;
-- ########## END: garden-v4-02c-tomato-monsoon-extend.sql ##########

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
-- garden-v4-07-seed-tomato-varieties.sql — auto-generated from brainstorm-inbox/Variety Assessments/Variety Assessment_Tomato.docx
-- Safe to re-run. Publishes cultivars for humid-subtropical + tropical-monsoon.

DO $$
DECLARE
  v_plant uuid;
  v_climate uuid;
  v_var uuid;
  v_ing integer;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'tomato' LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant tomato missing — seed species first'; END IF;
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
  SELECT v_plant, 'tigerella', 'Tigerella', 'heirloom', 'UK 1970s', 'Indeterminate, medium red-orange stripes', 'Sweet-tangy balanced, firm, colorful', 'Early-mid, productive', '', '', 3, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tigerella');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tigerella' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
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
  SELECT v_plant, 'arka-rakshak', 'Arka Rakshak', 'hybrid', 'IIHR Bangalore', 'Indeterminate, disease-resistant', 'Round, firm, good quality', '19 kg per plant, excellent yields', 'Kerala: HIGH-YIELDING & DISEASE-RESISTANT. Crossing high-yielding F1. Resistant to ToLCV, bacterial wilt, early blight. Specifically developed for South India. Excellent tropical monsoon performance.', 'Kerala nurseries, IIHR, Indian Agricultural suppliers', 1, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-rakshak');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-rakshak' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: HIGH-YIELDING & DISEASE-RESISTANT. Crossing high-yielding F1. Resistant to ToLCV, bacterial wilt, early blight. Specifically developed for South India. Excellent tropical monsoon performance.')
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
  SELECT v_plant, 'arka-saurabh', 'Arka Saurabh', 'hybrid', 'IIHR Bangalore hybrid', 'High-yielding, medium-sized juicy', 'Juicy, good quality', 'Adaptable to various climates', 'Kerala: High-yielding hybrid. Medium-sized juicy fruits. Preferred for adaptability to various climatic conditions including Kerala monsoon.', 'Kerala nurseries, IIHR', 4, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-saurabh');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-saurabh' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding hybrid. Medium-sized juicy fruits. Preferred for adaptability to various climatic conditions including Kerala monsoon.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Saurabh')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Arka Shrestha (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-shrestha', 'Arka Shrestha', 'hybrid', 'IIHR Bangalore', 'Semi-determinate, light green plants, 70-75g', 'Firm, long shelf life (17 days), easy transport', '76 tons/ha', 'Kerala: High-yielding hybrid. Particularly good for Kerala due to long shelf life in humid conditions. Easy transport. Kharif/Rabi season. Ripens after Rabi.', 'Kerala nurseries, IIHR Bangalore', 5, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-shrestha');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-shrestha' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding hybrid. Particularly good for Kerala due to long shelf life in humid conditions. Easy transport. Kharif/Rabi season. Ripens after Rabi.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Shrestha')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Arka Vikas (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-vikas', 'Arka Vikas', 'open_pollinated', 'IIHR Bangalore', 'Early-maturing, round red', 'Firm, suitable long-distance transportation', 'Good early yields', 'Kerala: Early-maturing for Kerala conditions. Firm texture important for transport in monsoon. Suitable fresh market. Good tropical performance.', 'Kerala nurseries, IIHR', 6, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-vikas');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-vikas' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Early-maturing for Kerala conditions. Firm texture important for transport in monsoon. Suitable fresh market. Good tropical performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Vikas')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Arka Ananya (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-ananya', 'Arka Ananya', 'hybrid', 'IIHR Bangalore', 'High-yielding, medium round red', 'Excellent quality', 'Excellent disease resistance', 'Kerala: High-yielding with excellent disease resistance - critical for Kerala monsoon. Medium-sized round red. Favourite among Kerala farmers.', 'Kerala nurseries, IIHR Bangalore', 7, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-ananya');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-ananya' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding with excellent disease resistance - critical for Kerala monsoon. Medium-sized round red. Favourite among Kerala farmers.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Ananya')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Arka Vishal (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'arka-vishal', 'Arka Vishal', 'hybrid', 'IIHR Bangalore', 'High-yielding, firm round dark red', 'Resistant to fruit cracking', '80 tons/ha', 'Kerala: ONE OF HIGHEST YIELDING. Fruits firm, round, dark red. Resist fruit cracking - important Kerala heavy rains. Excellent monsoon performance.', 'Kerala nurseries, IIHR', 8, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-vishal');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'arka-vishal' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: ONE OF HIGHEST YIELDING. Fruits firm, round, dark red. Resist fruit cracking - important Kerala heavy rains. Excellent monsoon performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Arka Vishal')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- TNAU Tomato Hybrid CO 3 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'tnau-tomato-hybrid-co-3', 'TNAU Tomato Hybrid CO 3', 'hybrid', 'Tamil Nadu Agricultural University', 'Developed for South Indian conditions', 'Good quality, disease resistant', 'Adapted specifically for South India', 'Kerala: DEVELOPED FOR SOUTH INDIA. Adapted to hot humid conditions similar to Kerala. Good disease resistance for monsoon. Regional breeding program.', 'Tamil Nadu suppliers, South Indian seed companies', 9, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tnau-tomato-hybrid-co-3');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'tnau-tomato-hybrid-co-3' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: DEVELOPED FOR SOUTH INDIA. Adapted to hot humid conditions similar to Kerala. Good disease resistance for monsoon. Regional breeding program.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: TNAU Tomato Hybrid CO 3')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Gaurav (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-gaurav', 'Pusa Gaurav', 'hybrid', 'IARI hybrid', 'Good disease resistance', 'Firm, juicy, suitable fresh and processing', 'High yield potential', 'Kerala: Hybrid with good disease resistance. Favoured by Kerala farmers for high yield potential. Adaptable to tropical monsoon conditions.', 'IARI, Indian seed suppliers', 10, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-gaurav');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-gaurav' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Hybrid with good disease resistance. Favoured by Kerala farmers for high yield potential. Adaptable to tropical monsoon conditions.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Gaurav')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Early Dwarf (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-early-dwarf', 'Pusa Early Dwarf', 'open_pollinated', 'IARI Delhi, early cultivar', 'Determinate, compact, round yellow stem end, furrowed', 'Medium-sized, uniform ripening', 'Matures 75-80 days after transplanting, 35 tons/ha', 'Kerala: Early growing cultivar. Quick returns for Kerala farmers. Suitable both spring-summer and autumn-winter. Good for table and processing.', 'IARI Delhi, widely available Kerala', 11, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-early-dwarf');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-early-dwarf' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Early growing cultivar. Quick returns for Kerala farmers. Suitable both spring-summer and autumn-winter. Good for table and processing.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Early Dwarf')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Sadabahar (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-sadabahar', 'Pusa Sadabahar', 'open_pollinated', 'IARI', 'Determinate, continuous fruiting', 'Good quality', 'Fruits throughout year', 'Kerala: Known for continuous fruiting throughout year. Excellent for Kerala''s year-round growing potential. Reliable production in tropical monsoon.', 'IARI, Indian seed companies', 12, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-sadabahar');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-sadabahar' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Known for continuous fruiting throughout year. Excellent for Kerala''s year-round growing potential. Reliable production in tropical monsoon.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Sadabahar')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Uphar (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-uphar', 'Pusa Uphar', 'open_pollinated', 'IARI', 'Determinate, round red', 'Good quality, early maturity', 'Good yields, suitable canning', 'Kerala: Determinate with early maturity. Round red fruits. Chosen for early maturity and canning suitability. Good Kerala adaptation.', 'IARI, processing suppliers', 13, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-uphar');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-uphar' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Determinate with early maturity. Round red fruits. Chosen for early maturity and canning suitability. Good Kerala adaptation.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Uphar')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Hybrid 4 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-hybrid-4', 'Pusa Hybrid 4', 'hybrid', 'IARI', 'Uniform fruit size, excellent shelf life', 'Firm, consistent quality', 'Good yields', 'Kerala: Popular hybrid. Uniform size and excellent shelf life important for Kerala humid conditions. Commonly used fresh market.', 'IARI, widely available', 14, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-hybrid-4');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-hybrid-4' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Popular hybrid. Uniform size and excellent shelf life important for Kerala humid conditions. Commonly used fresh market.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Hybrid 4')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Hybrid 8 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-hybrid-8', 'Pusa Hybrid 8', 'hybrid', 'IARI', 'Adaptable to various climates', 'Firm, juicy, suitable fresh and processing', 'Good yields', 'Kerala: Known for adaptability to various climates including Kerala tropical monsoon. Firm and juicy. Both fresh consumption and processing.', 'IARI, Indian seed suppliers', 15, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-hybrid-8');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-hybrid-8' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Known for adaptability to various climates including Kerala tropical monsoon. Firm and juicy. Both fresh consumption and processing.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Hybrid 8')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Abhinav (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'abhinav', 'Abhinav', 'hybrid', 'Semi-determinate, broad leaves, excellent foliage', 'Square, smooth, dark red, 80-100g', 'Good quality', 'High yields', 'Kerala: Semi-determinate with excellent foliage cover. Square smooth dark red fruits. Fantastic foliage cover protects from intense Kerala sun. Good monsoon adaptation.', 'Kerala nurseries, commercial suppliers', 16, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'abhinav');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'abhinav' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Semi-determinate with excellent foliage cover. Square smooth dark red fruits. Fantastic foliage cover protects from intense Kerala sun. Good monsoon adaptation.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Abhinav')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Namdhari (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'namdhari', 'Namdhari', 'hybrid', 'Determinate, early mature hybrid', '80-90g, attractive glossy red', 'Firm, good quality', 'Good early yields', 'Kerala: Determinate early mature hybrid. Attractive glossy red colour. Sowing August-October. Cultivated across almost all Kerala districts. Very popular.', 'Namdhari Seeds, widely available Kerala', 17, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'namdhari');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'namdhari' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Determinate early mature hybrid. Attractive glossy red colour. Sowing August-October. Cultivated across almost all Kerala districts. Very popular.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Namdhari')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Rashmi (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'rashmi', 'Rashmi', 'hybrid', 'Determinate, widely adapted hybrid', 'Round, firm, smooth, brightly coloured, 90g', 'Good quality, suitable processing', 'First harvest 70 days from planting', 'Kerala: Determinate widely adapted hybrid. Bright colouring. Suitable for processing. Good Kerala adaptation. Reliable first harvest 70 days.', 'Commercial suppliers, Kerala nurseries', 18, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'rashmi');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'rashmi' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Determinate widely adapted hybrid. Bright colouring. Suitable for processing. Good Kerala adaptation. Reliable first harvest 70 days.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Rashmi')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Vaishali (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'vaishali', 'Vaishali', 'hybrid', 'Determinate, hot humid adapted', 'Medium-sized (100g) quality fruits, suitable making fresh juice', 'Good juice quality', 'Good yields', 'Kerala: SUITABLE FOR HOT AND HUMID WEATHER - perfect Kerala! Determinate hybrid. Medium-sized quality fruits. Excellent for table and juice making.', 'Kerala nurseries, commercial suppliers', 19, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'vaishali');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'vaishali' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: SUITABLE FOR HOT AND HUMID WEATHER - perfect Kerala! Determinate hybrid. Medium-sized quality fruits. Excellent for table and juice making.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Vaishali')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Rupali (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'rupali', 'Rupali', 'hybrid', 'Determinate, compact, early hybrid', 'Medium (100g) round, firm, smooth, good quality', 'Deep red, good quality', 'Good yields', 'Kerala: Determinate compact-growing early hybrid. Good foliage cover. Medium-sized high quality. Appropriate for processing. Good Kerala monsoon performance.', 'Kerala nurseries, commercial suppliers', 20, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'rupali');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'rupali' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Determinate compact-growing early hybrid. Good foliage cover. Medium-sized high quality. Appropriate for processing. Good Kerala monsoon performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Rupali')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Nati/Desi Tomato (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'nati-desi-tomato', 'Nati/Desi Tomato', 'indigenous', 'Traditional Indian countryside varieties', 'Small-medium (40-60g), thin skin', 'Exceptional flavor, intense taste, traditional', 'Variable, adapted to local conditions', '', '', 21, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'nati-desi-tomato');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'nati-desi-tomato' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Nati/Desi Tomato')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Roma (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'roma', 'Roma', 'open_pollinated', 'Multiple varieties', 'Small, sweet, various colours, good containers', 'Sweet taste, good salads', 'Suitable Indian summers', 'Kerala: Renowned for Indian farmers. Versatile, adaptable various Indian soils. Plum-shaped ideal sauces. Thrives well-draining soils, can withstand heat. Perfect Indian tropical climate. Kerala: Gained immense popularity India. Sweet taste, capability grow various Indian soil conditions. Small size ideal small spaces, containers, transport, preserve. Suitable Kerala summers.', 'Very common - all Kerala nurseries', 22, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'roma');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'roma' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Renowned for Indian farmers. Versatile, adaptable various Indian soils. Plum-shaped ideal sauces. Thrives well-draining soils, can withstand heat. Perfect Indian tropical climate. Kerala: Gained immense popularity India. Sweet taste, capability grow various Indian soil conditions. Small size ideal small spaces, containers, transport, preserve. Suitable Kerala summers.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Roma')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Bangalore / Bettina (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'bangalore-bettina', 'Bangalore / Bettina', 'indigenous', 'Developed for South Indian conditions', 'Disease resistant', 'Powerful resistance diseases, pests common South India', 'Good yields', 'Kerala: SPECIFICALLY DEVELOPED FOR SOUTH INDIA! Perfect fit Indian tropical climate. Thrives range soil types. Endurance resist bacterial wilt, other microorganisms. Reliable choice Kerala farmers seeking consistent yields.', 'Bangalore nurseries, South Indian seed companies', 23, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bangalore-bettina');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bangalore-bettina' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: SPECIFICALLY DEVELOPED FOR SOUTH INDIA! Perfect fit Indian tropical climate. Thrives range soil types. Endurance resist bacterial wilt, other microorganisms. Reliable choice Kerala farmers seeking consistent yields.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Bangalore / Bettina')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pearl Tomato / Cherry Pear (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pearl-tomato-cherry-pear', 'Pearl Tomato / Cherry Pear', 'open_pollinated', 'Pear-shaped variety', 'Oblong, small, sweet, visually pleasing', 'Sweet taste', 'Good productivity', 'Kerala: Awesome choice Kerala farmers. Oblong shapes, small sizes visually pleasing. Preferred sweet taste. Grow containers, hanging baskets. Suitable urban Kerala gardening.', '', 24, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pearl-tomato-cherry-pear');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pearl-tomato-cherry-pear' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Awesome choice Kerala farmers. Oblong shapes, small sizes visually pleasing. Preferred sweet taste. Grow containers, hanging baskets. Suitable urban Kerala gardening.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pearl Tomato / Cherry Pear')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Punjab Kesari (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'punjab-kesari', 'Punjab Kesari', 'hybrid', 'Punjab Agricultural University', 'Medium-large, good quality', 'Disease resistant', 'High yielding, suitable processing', 'Kerala: High-yielding known for pest/disease resistance. Medium-large tomatoes suitable processing. Good adaptation to Kerala if available.', 'Punjab suppliers, may be available Kerala', 25, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-kesari');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-kesari' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding known for pest/disease resistance. Medium-large tomatoes suitable processing. Good adaptation to Kerala if available.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Punjab Kesari')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Punjab Chhuhara (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'punjab-chhuhara', 'Punjab Chhuhara', 'open_pollinated', 'Punjab variety', 'Pear shape, red, firm, thick skin, seedless', 'Good quality, long transport', '325 qtl/acre, 7 days shelf life after harvest', 'Kerala: Seedless pear shape. Marketable quality 7 days - good Kerala humid conditions. Suitable long-distance transportation and processing.', 'Punjab suppliers, specialty varieties', 26, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-chhuhara');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-chhuhara' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Seedless pear shape. Marketable quality 7 days - good Kerala humid conditions. Suitable long-distance transportation and processing.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Punjab Chhuhara')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Punjab Upma (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'punjab-upma', 'Punjab Upma', 'open_pollinated', 'Punjab, rainy season suitable', 'Oval, medium, firm deep red', 'Good quality', '220 qtl/acre', 'Kerala: SUITABLE CULTIVATION IN RAINY SEASON - perfect Kerala monsoon! Oval medium-sized firm deep red. Good yields.', 'Punjab suppliers, rainy season specialists', 27, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-upma');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-upma' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: SUITABLE CULTIVATION IN RAINY SEASON - perfect Kerala monsoon! Oval medium-sized firm deep red. Good yields.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Punjab Upma')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Punjab NR-7 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'punjab-nr-7', 'Punjab NR-7', 'open_pollinated', 'Punjab dwarf variety', 'Dwarf, medium juicy', 'Good flavor', 'Good yields', '', '', 28, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-nr-7');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-nr-7' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Punjab NR-7')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Syngenta Saaho (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'syngenta-saaho', 'Syngenta Saaho', 'hybrid', 'Syngenta for hot humid tropics', 'Delayed ripening, enhanced transportability, hardy', 'Firm, good quality', 'High yields in tropical open-field', 'Kerala: SPECIFICALLY BRED FOR HOT HUMID TROPICAL OPEN-FIELD - perfect Kerala! Delayed ripening, enhanced transportability, hardiness deliberately selected. ''Breeding by design'' for Kerala conditions. Disease/pest tolerant.', 'Syngenta dealers, major Kerala seed companies', 29, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'syngenta-saaho');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'syngenta-saaho' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: SPECIFICALLY BRED FOR HOT HUMID TROPICAL OPEN-FIELD - perfect Kerala! Delayed ripening, enhanced transportability, hardiness deliberately selected. ''Breeding by design'' for Kerala conditions. Disease/pest tolerant.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Syngenta Saaho')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Syngenta TO-1057 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'syngenta-to-1057', 'Syngenta TO-1057', 'hybrid', 'Syngenta hybrid', 'Semi-indeterminate, medium 70-80g', 'Exceptional quality, vibrant red', 'High yields', 'Kerala: High-yielding semi-indeterminate. Exceptional fruit quality. Adaptability to various climatic conditions including Kerala tropical. Resistance to major diseases. Thrives tropical and temperate.', 'Syngenta dealers, Kerala suppliers', 30, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'syngenta-to-1057');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'syngenta-to-1057' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding semi-indeterminate. Exceptional fruit quality. Adaptability to various climatic conditions including Kerala tropical. Resistance to major diseases. Thrives tropical and temperate.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Syngenta TO-1057')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Syngenta TO-6242 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'syngenta-to-6242', 'Syngenta TO-6242', 'hybrid', 'Syngenta high-performance', 'Semi-determinate, consistent firm glossy', 'Premium quality, ideal market', '20% higher yields, longer shelf life', 'Kerala: Higher yield potential, premium fruit quality. Longer shelf life - important Kerala humidity. Semi-determinate adapts diverse climates. Extended fruit setting. Enhanced disease resistance. Up to 20% higher yields.', 'Syngenta dealers, Kerala seed companies', 31, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'syngenta-to-6242');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'syngenta-to-6242' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Higher yield potential, premium fruit quality. Longer shelf life - important Kerala humidity. Semi-determinate adapts diverse climates. Extended fruit setting. Enhanced disease resistance. Up to 20% higher yields.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Syngenta TO-6242')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Seminis Abhilash (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'seminis-abhilash', 'Seminis Abhilash', 'hybrid', 'Seminis for rainy seasons', 'Good disease resistance, adaptable hotter climates', 'Sweet, juicy, attractive red', 'High yields, 65-70 days maturity', 'Kerala: F1 SPECIALLY DEVELOPED FOR RAINY SEASONS - perfect Kerala monsoon! Exceptional disease resistance. High yields. Adaptable hotter climates. Early maturity 65-70 days from transplanting. Reliable rainy season choice.', 'Seminis dealers, Kerala nurseries', 32, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'seminis-abhilash');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'seminis-abhilash' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: F1 SPECIALLY DEVELOPED FOR RAINY SEASONS - perfect Kerala monsoon! Exceptional disease resistance. High yields. Adaptable hotter climates. Early maturity 65-70 days from transplanting. Reliable rainy season choice.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Seminis Abhilash')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Melkasalsa & Melkashola (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'melkasalsa-melkashola', 'Melkasalsa & Melkashola', 'indigenous', 'Indigenous rainy season varieties', 'Small, flavourful, drought tolerant', 'Traditional flavour', 'Good yields rainy season', '', '', 33, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'melkasalsa-melkashola');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'melkasalsa-melkashola' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Melkasalsa & Melkashola')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Bhagyashri (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'bhagyashri', 'Bhagyashri', 'open_pollinated', 'Popular open-pollinated', 'Medium-sized', 'Sweet and tangy taste', 'Good yields', '', '', 34, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bhagyashri');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'bhagyashri' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Bhagyashri')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Paiyur-1 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'paiyur-1', 'Paiyur-1', 'open_pollinated', 'TNAU, crossing Pusa Ruby & CO3', 'Determinate, round, yellow stem end', 'Good quality', '30 tons/ha, suitable rainfed', 'Kerala: Type developed crossing Pusa Ruby and CO3. SUITABLE FOR RAINFED CULTIVATION - important Kerala monsoon areas. High-yielding determinate. Uniform ripening.', 'Tamil Nadu suppliers, South Indian seed companies', 35, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'paiyur-1');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'paiyur-1' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Type developed crossing Pusa Ruby and CO3. SUITABLE FOR RAINFED CULTIVATION - important Kerala monsoon areas. High-yielding determinate. Uniform ripening.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Paiyur-1')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Philippino (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'philippino', 'Philippino', 'open_pollinated', 'Hot-set variety from Philippines', 'Sets fruit above 20°C', 'Good tropical performance', 'Good yields hot conditions', '', '', 36, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'philippino');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'philippino' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Philippino')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Punjab Tropic (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'punjab-tropic', 'Punjab Tropic', 'open_pollinated', 'Punjab hot-set variety', 'Sets fruit above 20°C', 'Heat adapted', 'Good hot weather yields', '', '', 37, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-tropic');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'punjab-tropic' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Punjab Tropic')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Hybrid 1 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-hybrid-1', 'Pusa Hybrid 1', 'hybrid', 'IARI hot-set hybrid', 'Sets fruit above 20°C', 'Good quality, heat adapted', 'Good yields', 'Kerala: Hot-set hybrid. Sets fruits above 20°C. Good for Kerala tropical temperatures. Reliable in heat.', 'IARI, hot-set variety suppliers', 38, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-hybrid-1');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-hybrid-1' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Hot-set hybrid. Sets fruits above 20°C. Good for Kerala tropical temperatures. Reliable in heat.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Hybrid 1')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Sheetal (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-sheetal', 'Pusa Sheetal', 'open_pollinated', 'IARI cold-set variety', 'Sets fruit below 15°C', 'Good quality', 'Good cooler weather yields', '', '', 39, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-sheetal');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-sheetal' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Sheetal')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Avalanche (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'avalanche', 'Avalanche', 'open_pollinated', 'Cold-set variety', 'Sets fruit below 15°C', 'Good quality', 'Good cooler conditions', 'Kerala: Cold-set. Sets fruits below 15°C. Suitable Kerala high-range areas with cooler mountain climates.', 'Cold-set variety specialists', 40, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'avalanche');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'avalanche' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Cold-set. Sets fruits below 15°C. Suitable Kerala high-range areas with cooler mountain climates.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Avalanche')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pusa Swarnim (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pusa-swarnim', 'Pusa Swarnim', 'hybrid', 'IARI hybrid', 'High-yielding, good disease resistance', 'Good quality', 'High yields', 'Kerala: High-yielding hybrid. Good disease resistance important Kerala monsoon conditions. Reliable performance.', 'IARI, Kerala suppliers', 41, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-swarnim');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pusa-swarnim' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: High-yielding hybrid. Good disease resistance important Kerala monsoon conditions. Reliable performance.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pusa Swarnim')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- PKM-1 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pkm-1', 'PKM-1', 'open_pollinated', 'Tamil Nadu variety', 'Round, firm', 'Good quality', 'Good yields', '', '', 42, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pkm-1');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pkm-1' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: PKM-1')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- CO-3 (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'co-3', 'CO-3', 'open_pollinated', 'Coimbatore Agricultural University', 'Developed for South India', 'Good quality, disease resistant', 'Good yields', 'Kerala: Developed Coimbatore for South Indian conditions. Good disease resistance. Regional adaptation ensures Kerala suitability.', 'Tamil Nadu suppliers, CAU', 43, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'co-3');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'co-3' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Developed Coimbatore for South Indian conditions. Good disease resistance. Regional adaptation ensures Kerala suitability.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: CO-3')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Hisar Arun (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'hisar-arun', 'Hisar Arun', 'open_pollinated', 'Haryana variety', 'Good quality', 'Heat adapted', 'Good yields', '', '', 44, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'hisar-arun');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'hisar-arun' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Hisar Arun')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Hisar Lalit (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'hisar-lalit', 'Hisar Lalit', 'open_pollinated', 'Haryana variety', 'Good quality', 'Heat and disease adapted', 'Good yields', '', '', 45, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'hisar-lalit');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'hisar-lalit' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Hisar Lalit')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kottayam Local (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kottayam-local', 'Kottayam Local', 'indigenous', 'Kottayam district traditional', 'Medium-sized, adapted to central Kerala', 'Good flavor, traditional', 'Good local yields', '', '', 46, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kottayam-local');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kottayam-local' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kottayam Local')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Wayanad High-Range Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'wayanad-high-range-variety', 'Wayanad High-Range Variety', 'indigenous', 'Wayanad district, cooler climate adapted', 'Medium-sized, cooler adaptation', 'Good quality', 'Good high-range yields', '', '', 47, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'wayanad-high-range-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'wayanad-high-range-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Wayanad High-Range Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Malabar Cherry (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'malabar-cherry', 'Malabar Cherry', 'indigenous', 'North Kerala traditional', 'Small cherry, traditional', 'Sweet, traditional flavor', 'Good home garden', '', '', 48, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'malabar-cherry');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'malabar-cherry' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Malabar Cherry')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Palakkad Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'palakkad-variety', 'Palakkad Variety', 'indigenous', 'Palakkad district', 'Medium-sized, adapted', 'Good quality, traditional', 'Good yields', '', '', 49, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'palakkad-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'palakkad-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Palakkad Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Thrissur Local (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'thrissur-local', 'Thrissur Local', 'indigenous', 'Thrissur district', 'Medium-sized, traditional', 'Good flavor', 'Good local yields', '', '', 50, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thrissur-local');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thrissur-local' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Thrissur Local')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kannur Coastal Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kannur-coastal-variety', 'Kannur Coastal Variety', 'indigenous', 'Kannur district coastal', 'Medium-sized, coastal adapted', 'Good quality', 'Good coastal yields', '', '', 51, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kannur-coastal-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kannur-coastal-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kannur Coastal Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Idukki High-Range (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'idukki-high-range', 'Idukki High-Range', 'indigenous', 'Idukki district mountains', 'Medium-sized, mountain adapted', 'Good quality', 'Good high-altitude', '', '', 52, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'idukki-high-range');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'idukki-high-range' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Idukki High-Range')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kollam Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kollam-variety', 'Kollam Variety', 'indigenous', 'Kollam district', 'Medium-sized, traditional', 'Good flavor', 'Good yields', '', '', 53, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kollam-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kollam-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kollam Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Malappuram Local (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'malappuram-local', 'Malappuram Local', 'indigenous', 'Malappuram district', 'Medium-sized, traditional', 'Good quality', 'Good yields', '', '', 54, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'malappuram-local');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'malappuram-local' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Malappuram Local')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Ernakulam Market Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'ernakulam-market-variety', 'Ernakulam Market Variety', 'open_pollinated', 'Ernakulam commercial', 'Medium-large, market favorite', 'Good quality, transport', 'Good commercial yields', 'Kerala: Popular in Ernakulam markets. Good for commercial cultivation. Suitable transport. Adapted central Kerala commercial conditions.', 'Ernakulam suppliers, commercial nurseries', 55, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'ernakulam-market-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'ernakulam-market-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Popular in Ernakulam markets. Good for commercial cultivation. Suitable transport. Adapted central Kerala commercial conditions.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Ernakulam Market Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kozhikode Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kozhikode-variety', 'Kozhikode Variety', 'indigenous', 'Kozhikode district', 'Medium-sized, traditional', 'Good flavor', 'Good yields', '', '', 56, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kozhikode-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kozhikode-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kozhikode Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kasaragod Border Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kasaragod-border-variety', 'Kasaragod Border Variety', 'indigenous', 'Kasaragod district', 'Medium-sized, border region', 'Good quality', 'Good yields', '', '', 57, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kasaragod-border-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kasaragod-border-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kasaragod Border Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Alappuzha Backwater Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'alappuzha-backwater-variety', 'Alappuzha Backwater Variety', 'indigenous', 'Alappuzha district', 'Medium-sized, backwater adapted', 'Good quality', 'Good waterlogged tolerance', '', '', 58, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'alappuzha-backwater-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'alappuzha-backwater-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Alappuzha Backwater Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Pathanamthitta Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'pathanamthitta-variety', 'Pathanamthitta Variety', 'indigenous', 'Pathanamthitta district', 'Medium-sized, traditional', 'Good flavor', 'Good yields', '', '', 59, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pathanamthitta-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'pathanamthitta-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Pathanamthitta Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kochi Urban Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kochi-urban-variety', 'Kochi Urban Variety', 'open_pollinated', 'Kochi urban adapted', 'Medium-sized, good containers', 'Good quality', 'Good urban yields', 'Kerala: Adapted to urban Kochi conditions. Good for container growing in urban Kerala settings. City-adapted strain.', 'Kochi nurseries, urban gardening', 60, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kochi-urban-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kochi-urban-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Adapted to urban Kochi conditions. Good for container growing in urban Kerala settings. City-adapted strain.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kochi Urban Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Thiruvananthapuram Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'thiruvananthapuram-variety', 'Thiruvananthapuram Variety', 'indigenous', 'Capital city region', 'Medium-sized, traditional', 'Good quality', 'Good yields', '', '', 61, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thiruvananthapuram-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'thiruvananthapuram-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Thiruvananthapuram Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Palghat Gap Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'palghat-gap-variety', 'Palghat Gap Variety', 'indigenous', 'Palakkad gap region', 'Medium-sized, gap climate', 'Good quality', 'Good yields', 'Kerala: Specifically adapted to Palakkad gap climate. The gap between Western Ghats affects climate. Unique adaptation to gap conditions.', 'Palakkad gap suppliers, regional markets', 62, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'palghat-gap-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'palghat-gap-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Specifically adapted to Palakkad gap climate. The gap between Western Ghats affects climate. Unique adaptation to gap conditions.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Palghat Gap Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kerala Container Cherry (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kerala-container-cherry', 'Kerala Container Cherry', 'open_pollinated', 'Modern Kerala adaptation', 'Small cherry, container suitable', 'Sweet, good quality', 'Good container yields', '', '', 63, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kerala-container-cherry');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kerala-container-cherry' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', '')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kerala Container Cherry')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Kerala Monsoon Special (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'kerala-monsoon-special', 'Kerala Monsoon Special', 'hybrid', 'Modern Kerala hybrid', 'Monsoon-resistant hybrid', 'Good quality, disease resistant', 'High yields monsoon', 'Kerala: Modern hybrid specifically developed for Kerala monsoon conditions. Enhanced disease resistance for heavy rainfall. Good yields during challenging monsoon period.', 'Modern Kerala seed companies, hybrid specialists', 64, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kerala-monsoon-special');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'kerala-monsoon-special' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: Modern hybrid specifically developed for Kerala monsoon conditions. Enhanced disease resistance for heavy rainfall. Good yields during challenging monsoon period.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Kerala Monsoon Special')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

  -- Athirappilly Variety (tropical-monsoon)
  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)
  SELECT v_plant, 'athirappilly-variety', 'Athirappilly Variety', 'indigenous', 'Thrissur district waterfall region', 'Medium-sized, high rainfall adapted', 'Good quality', 'Good high-rainfall yields', 'Kerala: From Athirappilly region with very high rainfall. Adapted to extremely wet conditions. Good for Kerala''s wettest areas.', 'Thrissur suppliers, high-rainfall specialists', 65, true
  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'athirappilly-variety');
  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = 'athirappilly-variety' LIMIT 1;
  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    VALUES (v_var, v_climate, 'recommended', 'Kerala: From Athirappilly region with very high rainfall. Adapted to extremely wet conditions. Good for Kerala''s wettest areas.')
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
    IF v_ing IS NOT NULL THEN
      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
      VALUES (v_var, v_ing, 'fruit', true, 'Variety: Athirappilly Variety')
      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
    END IF;
  END IF;

END $$;

INSERT INTO public.garden_import_queue (source_path, species_name, species_slug, climate_slug, status, variety_count, payload, processed_at)
VALUES ('brainstorm-inbox/Variety Assessments/Variety Assessment_Tomato.docx', 'Tomato', 'tomato', 'multi', 'approved', 91,
 '{"generated": true, "variety_count": 91}'::jsonb, now())
ON CONFLICT DO NOTHING;

SELECT 'ready — 91 varieties for tomato' AS status;
-- ########## END: garden-v4-07-seed-tomato-varieties.sql ##########

-- ########## BEGIN: garden-v4-08-lookups.sql ##########
-- garden-v4-08-lookups.sql — additional lookup vocab from Garden Database manual (slice 2)

INSERT INTO public.soil_types (slug, name, ph_low, ph_high) VALUES
  ('loam', 'Loam', 6.0, 7.0),
  ('sandy-loam', 'Sandy loam', 5.5, 7.0),
  ('clay-loam', 'Clay loam', 6.0, 7.5),
  ('potting-mix', 'Premium potting mix', 5.5, 6.5),
  ('compost-rich', 'Compost-rich bed', 6.0, 7.0)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.sunlight_levels (slug, name, hours) VALUES
  ('full-sun', 'Full sun', '6+ hours direct'),
  ('part-sun', 'Part sun', '4–6 hours'),
  ('part-shade', 'Part shade', '2–4 hours'),
  ('bright-indirect', 'Bright indirect', 'Bright, no direct midday')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.growth_habits (slug, name, description) VALUES
  ('bush', 'Bush / determinate', 'Compact, stops at set height.'),
  ('spreading', 'Spreading / ground cover', 'Low horizontal spread.'),
  ('upright', 'Upright / columnar', 'Vertical habit, minimal spread.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.cat_main (slug, name, definition) VALUES
  ('leafy-greens', 'Leafy greens', 'Grown primarily for leaves.'),
  ('herbs-aromatic', 'Herbs & aromatics', 'Culinary herbs and scented plants.'),
  ('root-tuber', 'Roots & tubers', 'Edible underground storage organs.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.tags (slug, name) VALUES
  ('monsoon-crop', 'Monsoon-season crop'),
  ('heat-tolerant', 'Heat tolerant'),
  ('humidity-adapted', 'Humidity adapted'),
  ('container-suitable', 'Container suitable'),
  ('fruit-fly-risk', 'Fruit fly — net fruit')
ON CONFLICT (slug) DO NOTHING;

SELECT 'garden-v4-08-lookups ready' AS status;
-- ########## END: garden-v4-08-lookups.sql ##########

-- ########## BEGIN: garden-v4-09-import-rpcs.sql ##########
-- garden-v4-09-import-rpcs.sql — admin apply garden import queue + species patch

CREATE OR REPLACE FUNCTION public.admin_apply_garden_import(p_queue_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row garden_import_queue%ROWTYPE;
  v_plant uuid;
  v_climate uuid;
  v_var uuid;
  v_ing integer;
  v_item jsonb;
  v_slug text;
  v_inserted int := 0;
  v_updated int := 0;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'admin only';
  END IF;

  SELECT * INTO v_row FROM garden_import_queue WHERE id = p_queue_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'import queue row not found';
  END IF;
  IF v_row.payload IS NULL OR v_row.payload->'varieties' IS NULL THEN
    RAISE EXCEPTION 'payload missing varieties array';
  END IF;

  SELECT id INTO v_plant FROM plants WHERE slug = COALESCE(v_row.species_slug, v_row.payload->>'species_slug') LIMIT 1;
  IF v_plant IS NULL THEN
    RAISE EXCEPTION 'species plant row missing for slug % — seed species before applying cultivars',
      COALESCE(v_row.species_slug, v_row.payload->>'species_slug');
  END IF;

  SELECT "ID" INTO v_ing FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%' || lower(COALESCE(v_row.species_slug, '')) || '%'
  ORDER BY "ID" LIMIT 1;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_row.payload->'varieties')
  LOOP
    v_slug := v_item->>'slug';
    IF v_slug IS NULL OR v_slug = '' THEN
      CONTINUE;
    END IF;

    INSERT INTO plant_varieties (
      plant_id, slug, name, lineage_type, origin, traits, flesh_fruit,
      yield_notes, growing_notes, availability, sort_order, is_published
    ) VALUES (
      v_plant,
      v_slug,
      COALESCE(v_item->>'name', v_slug),
      COALESCE(v_item->>'lineage_type', 'open_pollinated'),
      v_item->>'origin',
      v_item->>'traits',
      COALESCE(v_item->>'flesh_fruit', v_item->>'flesh'),
      COALESCE(v_item->>'yield_notes', v_item->>'yield'),
      COALESCE(v_item->>'growing_notes', v_item->>'notes'),
      v_item->>'availability',
      COALESCE((v_item->>'sort_order')::int, 0),
      true
    )
    ON CONFLICT (plant_id, slug) DO UPDATE SET
      name = EXCLUDED.name,
      lineage_type = EXCLUDED.lineage_type,
      origin = EXCLUDED.origin,
      traits = EXCLUDED.traits,
      flesh_fruit = EXCLUDED.flesh_fruit,
      yield_notes = EXCLUDED.yield_notes,
      growing_notes = EXCLUDED.growing_notes,
      availability = EXCLUDED.availability,
      sort_order = EXCLUDED.sort_order,
      is_published = true,
      updated_at = now()
    RETURNING id INTO v_var;

    v_inserted := v_inserted + 1;

    SELECT id INTO v_climate FROM climate_zones WHERE slug = v_item->>'climate_slug' LIMIT 1;
    IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
      INSERT INTO variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
      VALUES (
        v_var, v_climate, 'recommended',
        left(COALESCE(v_item->>'growing_notes', v_item->>'notes', ''), 500)
      )
      ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
      v_updated := v_updated + 1;

      IF v_ing IS NOT NULL THEN
        INSERT INTO variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
        VALUES (v_var, v_ing, 'fruit', true, 'Variety: ' || COALESCE(v_item->>'name', v_slug))
        ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
      END IF;
    END IF;
  END LOOP;

  UPDATE garden_import_queue
  SET status = 'approved', processed_at = now(), variety_count = v_inserted
  WHERE id = p_queue_id;

  RETURN jsonb_build_object(
    'queue_id', p_queue_id,
    'species_slug', v_row.species_slug,
    'varieties_upserted', v_inserted,
    'climate_links', v_updated
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_apply_garden_import(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_patch_garden_species(
  p_slug text,
  p_fields jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_allowed text[] := ARRAY[
    'common_name', 'botanical_name', 'plant_family', 'plant_type', 'origin',
    'size_height', 'size_spread', 'care_summary', 'genetic_lineage_type',
    'variety_cultivar', 'growth_rate', 'time_to_harvest', 'harvest_season',
    'edible_parts', 'culinary_applications', 'is_published'
  ];
  v_key text;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  IF p_slug IS NULL OR p_slug = '' THEN
    RAISE EXCEPTION 'slug required';
  END IF;

  SELECT id INTO v_id FROM plants WHERE slug = p_slug LIMIT 1;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'plant not found: %', p_slug;
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_fields)
  LOOP
    IF v_key = ANY(v_allowed) THEN
      EXECUTE format(
        'UPDATE plants SET %I = ($1->>$2), updated_at = now() WHERE id = $3',
        v_key
      ) USING p_fields, v_key, v_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('slug', p_slug, 'updated', p_fields);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_patch_garden_species(text, jsonb) TO authenticated;

SELECT 'garden-v4-09-import-rpcs ready' AS status;
-- ########## END: garden-v4-09-import-rpcs.sql ##########

-- ########## BEGIN: garden-v4-11-lookup-admin-rpcs.sql ##########
-- garden-v4-11-lookup-admin-rpcs.sql — GM lookup CRUD + merge/delete with FK propagation

CREATE OR REPLACE FUNCTION public.admin_get_garden_lookup_usage(p_table text, p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v jsonb := '{}'::jsonb;
  v_n int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF p_id IS NULL THEN RAISE EXCEPTION 'id required'; END IF;

  CASE p_table
    WHEN 'cat_high_level' THEN
      SELECT count(*)::int INTO v_n FROM plants WHERE high_level_category_id = p_id;
      v := v || jsonb_build_object('plants', v_n);
    WHEN 'cat_main' THEN
      SELECT count(*)::int INTO v_n FROM plants WHERE main_category_id = p_id;
      v := v || jsonb_build_object('plants', v_n);
    WHEN 'growth_habits' THEN
      SELECT count(*)::int INTO v_n FROM plants WHERE growth_habit_id = p_id;
      v := v || jsonb_build_object('plants', v_n);
    WHEN 'garden_layers' THEN
      SELECT count(*)::int INTO v_n FROM plants WHERE garden_layer_id = p_id;
      v := v || jsonb_build_object('plants', v_n);
    WHEN 'lifecycles' THEN
      SELECT count(*)::int INTO v_n FROM plants WHERE lifecycle_id = p_id;
      v := v || jsonb_build_object('plants', v_n);
    WHEN 'ease_ratings' THEN
      SELECT count(*)::int INTO v_n FROM plants WHERE ease_rating_id = p_id;
      v := v || jsonb_build_object('plants', v_n);
    WHEN 'seed_saving_groups' THEN
      SELECT count(*)::int INTO v_n FROM plants WHERE seed_saving_group_id = p_id;
      v := v || jsonb_build_object('plants', v_n);
    WHEN 'climate_zones' THEN
      SELECT count(*)::int INTO v_n FROM plant_climate_care WHERE climate_zone_id = p_id;
      v := v || jsonb_build_object('plant_climate_care', v_n);
      SELECT count(*)::int INTO v_n FROM plant_calendar WHERE climate_zone_id = p_id;
      v := v || jsonb_build_object('plant_calendar', v_n);
      SELECT count(*)::int INTO v_n FROM variety_climate_suitability WHERE climate_zone_id = p_id;
      v := v || jsonb_build_object('variety_climate_suitability', v_n);
      SELECT count(*)::int INTO v_n FROM regions WHERE climate_zone_id = p_id;
      v := v || jsonb_build_object('regions', v_n);
    WHEN 'regions' THEN
      SELECT count(*)::int INTO v_n FROM plant_culture WHERE region_id = p_id;
      v := v || jsonb_build_object('plant_culture', v_n);
    WHEN 'tags' THEN
      SELECT count(*)::int INTO v_n FROM entity_tags WHERE tag_id = p_id;
      v := v || jsonb_build_object('entity_tags', v_n);
    WHEN 'soil_types', 'sunlight_levels', 'zone_definitions' THEN
      v := v || jsonb_build_object('direct_fk', 0);
    ELSE
      RAISE EXCEPTION 'unsupported table: %', p_table;
  END CASE;

  RETURN v || jsonb_build_object('table', p_table, 'id', p_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_merge_garden_lookup(
  p_table text,
  p_from_id uuid,
  p_to_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_counts jsonb := '{}'::jsonb;
  v_n int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF p_from_id IS NULL OR p_to_id IS NULL OR p_from_id = p_to_id THEN
    RAISE EXCEPTION 'invalid merge ids';
  END IF;

  CASE p_table
    WHEN 'cat_high_level' THEN
      UPDATE plants SET high_level_category_id = p_to_id, updated_at = now()
      WHERE high_level_category_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plants', v_n);
    WHEN 'cat_main' THEN
      UPDATE plants SET main_category_id = p_to_id, updated_at = now() WHERE main_category_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plants', v_n);
    WHEN 'growth_habits' THEN
      UPDATE plants SET growth_habit_id = p_to_id, updated_at = now() WHERE growth_habit_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plants', v_n);
    WHEN 'garden_layers' THEN
      UPDATE plants SET garden_layer_id = p_to_id, updated_at = now() WHERE garden_layer_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plants', v_n);
    WHEN 'lifecycles' THEN
      UPDATE plants SET lifecycle_id = p_to_id, updated_at = now() WHERE lifecycle_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plants', v_n);
    WHEN 'ease_ratings' THEN
      UPDATE plants SET ease_rating_id = p_to_id, updated_at = now() WHERE ease_rating_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plants', v_n);
    WHEN 'seed_saving_groups' THEN
      UPDATE plants SET seed_saving_group_id = p_to_id, updated_at = now() WHERE seed_saving_group_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plants', v_n);
    WHEN 'climate_zones' THEN
      UPDATE plant_climate_care SET climate_zone_id = p_to_id WHERE climate_zone_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plant_climate_care', v_n);
      UPDATE plant_calendar SET climate_zone_id = p_to_id WHERE climate_zone_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plant_calendar', v_n);
      UPDATE variety_climate_suitability SET climate_zone_id = p_to_id WHERE climate_zone_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('variety_climate_suitability', v_n);
      UPDATE regions SET climate_zone_id = p_to_id WHERE climate_zone_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('regions', v_n);
    WHEN 'regions' THEN
      UPDATE plant_culture SET region_id = p_to_id WHERE region_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('plant_culture', v_n);
    WHEN 'tags' THEN
      DELETE FROM entity_tags et
      USING entity_tags dup
      WHERE et.tag_id = p_from_id AND dup.tag_id = p_to_id
        AND dup.entity_type = et.entity_type AND dup.entity_id = et.entity_id;
      UPDATE entity_tags SET tag_id = p_to_id WHERE tag_id = p_from_id;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_counts := v_counts || jsonb_build_object('entity_tags', v_n);
    ELSE
      RAISE EXCEPTION 'merge not supported for %', p_table;
  END CASE;

  EXECUTE format('DELETE FROM public.%I WHERE id = $1', p_table) USING p_from_id;

  RETURN jsonb_build_object('merged', true, 'from', p_from_id, 'to', p_to_id, 'updated', v_counts);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_garden_lookup(p_table text, p_row jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_slug text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  v_slug := lower(regexp_replace(trim(COALESCE(p_row->>'slug', p_row->>'name', '')), '[^a-z0-9]+', '-', 'g'), '-');

  CASE p_table
    WHEN 'cat_high_level' THEN
      INSERT INTO cat_high_level (id, slug, name, definition)
      VALUES (
        COALESCE((p_row->>'id')::uuid, gen_random_uuid()),
        COALESCE(NULLIF(p_row->>'slug',''), v_slug),
        COALESCE(p_row->>'name', 'Unnamed'),
        p_row->>'definition'
      )
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name, definition = EXCLUDED.definition
      RETURNING id INTO v_id;
    WHEN 'cat_main' THEN
      INSERT INTO cat_main (id, slug, name, definition)
      VALUES (COALESCE((p_row->>'id')::uuid, gen_random_uuid()), COALESCE(NULLIF(p_row->>'slug',''), v_slug), COALESCE(p_row->>'name','Unnamed'), p_row->>'definition')
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, definition = EXCLUDED.definition
      RETURNING id INTO v_id;
    WHEN 'garden_layers' THEN
      INSERT INTO garden_layers (id, slug, name, description)
      VALUES (COALESCE((p_row->>'id')::uuid, gen_random_uuid()), COALESCE(NULLIF(p_row->>'slug',''), v_slug), COALESCE(p_row->>'name','Unnamed'), p_row->>'description')
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description
      RETURNING id INTO v_id;
    WHEN 'growth_habits' THEN
      INSERT INTO growth_habits (id, slug, name, description)
      VALUES (COALESCE((p_row->>'id')::uuid, gen_random_uuid()), COALESCE(NULLIF(p_row->>'slug',''), v_slug), COALESCE(p_row->>'name','Unnamed'), p_row->>'description')
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description
      RETURNING id INTO v_id;
    WHEN 'lifecycles' THEN
      INSERT INTO lifecycles (id, slug, name, traits)
      VALUES (COALESCE((p_row->>'id')::uuid, gen_random_uuid()), COALESCE(NULLIF(p_row->>'slug',''), v_slug), COALESCE(p_row->>'name','Unnamed'), p_row->>'traits')
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, traits = EXCLUDED.traits
      RETURNING id INTO v_id;
    WHEN 'soil_types' THEN
      INSERT INTO soil_types (id, slug, name, ph_low, ph_high)
      VALUES (
        COALESCE((p_row->>'id')::uuid, gen_random_uuid()),
        COALESCE(NULLIF(p_row->>'slug',''), v_slug),
        COALESCE(p_row->>'name','Unnamed'),
        NULLIF(p_row->>'ph_low','')::numeric,
        NULLIF(p_row->>'ph_high','')::numeric
      )
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, ph_low = EXCLUDED.ph_low, ph_high = EXCLUDED.ph_high
      RETURNING id INTO v_id;
    WHEN 'sunlight_levels' THEN
      INSERT INTO sunlight_levels (id, slug, name, hours)
      VALUES (COALESCE((p_row->>'id')::uuid, gen_random_uuid()), COALESCE(NULLIF(p_row->>'slug',''), v_slug), COALESCE(p_row->>'name','Unnamed'), p_row->>'hours')
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, hours = EXCLUDED.hours
      RETURNING id INTO v_id;
    WHEN 'seed_saving_groups' THEN
      INSERT INTO seed_saving_groups (id, grp, name, notes)
      VALUES (
        COALESCE((p_row->>'id')::uuid, gen_random_uuid()),
        COALESCE((p_row->>'grp')::smallint, 0),
        COALESCE(p_row->>'name','Unnamed'),
        p_row->>'notes'
      )
      ON CONFLICT (grp) DO UPDATE SET name = EXCLUDED.name, notes = EXCLUDED.notes
      RETURNING id INTO v_id;
    WHEN 'ease_ratings' THEN
      INSERT INTO ease_ratings (id, score, name, definition)
      VALUES (
        COALESCE((p_row->>'id')::uuid, gen_random_uuid()),
        COALESCE((p_row->>'score')::smallint, 1),
        COALESCE(p_row->>'name','Unnamed'),
        p_row->>'definition'
      )
      ON CONFLICT (score) DO UPDATE SET name = EXCLUDED.name, definition = EXCLUDED.definition
      RETURNING id INTO v_id;
    WHEN 'climate_zones' THEN
      INSERT INTO climate_zones (id, slug, name)
      VALUES (COALESCE((p_row->>'id')::uuid, gen_random_uuid()), COALESCE(NULLIF(p_row->>'slug',''), v_slug), COALESCE(p_row->>'name','Unnamed'))
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
      RETURNING id INTO v_id;
    WHEN 'regions' THEN
      INSERT INTO regions (id, slug, name, climate_zone_id, is_active)
      VALUES (
        COALESCE((p_row->>'id')::uuid, gen_random_uuid()),
        COALESCE(NULLIF(p_row->>'slug',''), v_slug),
        COALESCE(p_row->>'name','Unnamed'),
        NULLIF(p_row->>'climate_zone_id','')::uuid,
        COALESCE((p_row->>'is_active')::boolean, true)
      )
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name, climate_zone_id = EXCLUDED.climate_zone_id, is_active = EXCLUDED.is_active
      RETURNING id INTO v_id;
    WHEN 'zone_definitions' THEN
      INSERT INTO zone_definitions (id, zone, name, description)
      VALUES (
        COALESCE((p_row->>'id')::uuid, gen_random_uuid()),
        COALESCE((p_row->>'zone')::smallint, 0),
        COALESCE(p_row->>'name','Unnamed'),
        p_row->>'description'
      )
      ON CONFLICT (zone) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description
      RETURNING id INTO v_id;
    WHEN 'tags' THEN
      INSERT INTO tags (id, slug, name)
      VALUES (COALESCE((p_row->>'id')::uuid, gen_random_uuid()), COALESCE(NULLIF(p_row->>'slug',''), v_slug), COALESCE(p_row->>'name','Unnamed'))
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
      RETURNING id INTO v_id;
    ELSE
      RAISE EXCEPTION 'unsupported table: %', p_table;
  END CASE;

  RETURN jsonb_build_object('id', v_id, 'table', p_table);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_garden_lookup(
  p_table text,
  p_id uuid,
  p_reassign_to uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usage jsonb;
  v_total int := 0;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF p_id IS NULL THEN RAISE EXCEPTION 'id required'; END IF;

  IF p_reassign_to IS NOT NULL THEN
    RETURN admin_merge_garden_lookup(p_table, p_id, p_reassign_to);
  END IF;

  v_usage := admin_get_garden_lookup_usage(p_table, p_id);
  SELECT coalesce(sum(
    CASE WHEN key NOT IN ('table', 'id') THEN (value#>>'{}')::int ELSE 0 END
  ), 0) INTO v_total FROM jsonb_each(v_usage);

  IF v_total > 0 THEN
    RAISE EXCEPTION 'lookup in use (% references). Merge into another row first.', v_total;
  END IF;

  EXECUTE format('DELETE FROM public.%I WHERE id = $1', p_table) USING p_id;
  RETURN jsonb_build_object('deleted', true, 'id', p_id, 'table', p_table);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_garden_lookup_usage(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_merge_garden_lookup(text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_garden_lookup(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_garden_lookup(text, uuid, uuid) TO authenticated;

SELECT 'garden-v4-11-lookup-admin-rpcs ready' AS status;
-- ########## END: garden-v4-11-lookup-admin-rpcs.sql ##########

-- ########## BEGIN: garden-v4-12-content-admin-rpcs.sql ##########
-- garden-v4-12-content-admin-rpcs.sql — species, cultivar, care, calendar admin editors

CREATE OR REPLACE FUNCTION public.admin_patch_garden_species(
  p_slug text,
  p_fields jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_allowed text[] := ARRAY[
    'common_name', 'botanical_name', 'plant_family', 'plant_type', 'origin', 'subspecies',
    'size_height', 'size_spread', 'care_summary', 'genetic_lineage_type', 'variety_cultivar',
    'growth_rate', 'time_to_harvest', 'harvest_season', 'edible_parts', 'culinary_applications',
    'toxic_parts', 'wildlife_attraction', 'propagation_methods', 'germination_time',
    'planting_windows', 'pollination_type', 'flowering_season', 'harvesting_method',
    'yield_per_plant', 'high_level_category_id', 'main_category_id', 'growth_habit_id',
    'garden_layer_id', 'lifecycle_id', 'ease_rating_id', 'seed_saving_group_id', 'is_published'
  ];
  v_key text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  IF p_slug IS NULL OR p_slug = '' THEN RAISE EXCEPTION 'slug required'; END IF;

  SELECT id INTO v_id FROM plants WHERE slug = p_slug LIMIT 1;
  IF v_id IS NULL THEN RAISE EXCEPTION 'plant not found: %', p_slug;

  FOR v_key IN SELECT jsonb_object_keys(p_fields)
  LOOP
    IF v_key = ANY(v_allowed) THEN
      EXECUTE format('UPDATE plants SET %I = ($1->>$2), updated_at = now() WHERE id = $3', v_key)
      USING p_fields, v_key, v_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('slug', p_slug, 'updated', p_fields);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_garden_species(p_row jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_slug text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;
  v_slug := lower(regexp_replace(trim(COALESCE(p_row->>'slug', p_row->>'common_name', '')), '[^a-z0-9]+', '-', 'g'), '-');
  IF v_slug = '' THEN RAISE EXCEPTION 'slug or common_name required'; END IF;

  INSERT INTO plants (slug, common_name, botanical_name, plant_family, plant_type, origin, care_summary, is_published)
  VALUES (
    v_slug,
    COALESCE(p_row->>'common_name', initcap(replace(v_slug, '-', ' '))),
    p_row->>'botanical_name',
    p_row->>'plant_family',
    p_row->>'plant_type',
    p_row->>'origin',
    p_row->>'care_summary',
    COALESCE((p_row->>'is_published')::boolean, false)
  )
  ON CONFLICT (slug) DO UPDATE SET
    common_name = EXCLUDED.common_name,
    botanical_name = COALESCE(EXCLUDED.botanical_name, plants.botanical_name),
    updated_at = now()
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('id', v_id, 'slug', v_slug);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_garden_cultivar(p_row jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plant uuid;
  v_id uuid;
  v_slug text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;

  v_id := NULLIF(p_row->>'id', '')::uuid;
  IF v_id IS NOT NULL THEN
    UPDATE plant_varieties SET
      name = COALESCE(p_row->>'name', name),
      lineage_type = COALESCE(p_row->>'lineage_type', lineage_type),
      origin = COALESCE(p_row->>'origin', origin),
      traits = COALESCE(p_row->>'traits', traits),
      flesh_fruit = COALESCE(p_row->>'flesh_fruit', flesh_fruit),
      yield_notes = COALESCE(p_row->>'yield_notes', yield_notes),
      growing_notes = COALESCE(p_row->>'growing_notes', growing_notes),
      availability = COALESCE(p_row->>'availability', availability),
      is_published = COALESCE((p_row->>'is_published')::boolean, is_published),
      updated_at = now()
    WHERE id = v_id
    RETURNING id, slug, plant_id INTO v_id, v_slug, v_plant;
    IF v_id IS NULL THEN RAISE EXCEPTION 'cultivar not found'; END IF;
    RETURN jsonb_build_object('id', v_id, 'slug', v_slug);
  END IF;

  SELECT id INTO v_plant FROM plants
  WHERE slug = COALESCE(p_row->>'plant_slug', p_row->>'species_slug') LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found';

  v_slug := lower(regexp_replace(trim(COALESCE(p_row->>'slug', p_row->>'name', '')), '[^a-z0-9]+', '-', 'g'), '-');

  INSERT INTO plant_varieties (
    id, plant_id, slug, name, lineage_type, origin, traits, flesh_fruit,
    yield_notes, growing_notes, availability, sort_order, is_published
  ) VALUES (
    COALESCE((p_row->>'id')::uuid, gen_random_uuid()),
    v_plant, v_slug,
    COALESCE(p_row->>'name', v_slug),
    COALESCE(p_row->>'lineage_type', 'open_pollinated'),
    p_row->>'origin', p_row->>'traits', p_row->>'flesh_fruit',
    p_row->>'yield_notes', p_row->>'growing_notes', p_row->>'availability',
    COALESCE((p_row->>'sort_order')::int, 0),
    COALESCE((p_row->>'is_published')::boolean, true)
  )
  ON CONFLICT (plant_id, slug) DO UPDATE SET
    name = EXCLUDED.name, lineage_type = EXCLUDED.lineage_type,
    origin = EXCLUDED.origin, traits = EXCLUDED.traits,
    flesh_fruit = EXCLUDED.flesh_fruit, yield_notes = EXCLUDED.yield_notes,
    growing_notes = EXCLUDED.growing_notes, availability = EXCLUDED.availability,
    sort_order = EXCLUDED.sort_order, is_published = EXCLUDED.is_published,
    updated_at = now()
  RETURNING id INTO v_id;

  IF p_row->>'climate_slug' IS NOT NULL AND p_row->>'climate_slug' <> '' THEN
    INSERT INTO variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
    SELECT v_id, cz.id, 'recommended', left(COALESCE(p_row->>'growing_notes',''), 500)
    FROM climate_zones cz WHERE cz.slug = p_row->>'climate_slug'
    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
  END IF;

  RETURN jsonb_build_object('id', v_id, 'slug', v_slug);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_plant_care(p_row jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plant uuid;
  v_climate uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;

  SELECT id INTO v_plant FROM plants WHERE slug = p_row->>'plant_slug' LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found';

  SELECT id INTO v_climate FROM climate_zones WHERE slug = p_row->>'climate_slug' LIMIT 1;
  IF v_climate IS NULL THEN RAISE EXCEPTION 'climate not found';

  INSERT INTO plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
  VALUES (
    v_plant, v_climate,
    COALESCE(p_row->>'field_key', 'custom'),
    p_row->>'core', p_row->>'risk', p_row->>'fix'
  )
  ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
    core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

  RETURN jsonb_build_object('plant_slug', p_row->>'plant_slug', 'field_key', p_row->>'field_key');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_plant_calendar(p_row jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plant uuid;
  v_climate uuid;
  v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'admin only'; END IF;

  SELECT id INTO v_plant FROM plants WHERE slug = p_row->>'plant_slug' LIMIT 1;
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found';

  SELECT id INTO v_climate FROM climate_zones WHERE slug = p_row->>'climate_slug' LIMIT 1;
  IF v_climate IS NULL THEN RAISE EXCEPTION 'climate not found';

  v_id := NULLIF(p_row->>'id', '')::uuid;
  IF v_id IS NOT NULL THEN
    UPDATE plant_calendar SET
      activity = COALESCE(p_row->>'activity', activity),
      month_start = COALESCE((p_row->>'month_start')::smallint, month_start),
      month_end = COALESCE((p_row->>'month_end')::smallint, month_end),
      notes = COALESCE(p_row->>'notes', notes),
      climate_zone_id = v_climate
    WHERE id = v_id AND plant_id = v_plant;
  ELSE
    INSERT INTO plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    VALUES (
      v_plant, v_climate,
      COALESCE(p_row->>'activity', 'sow'),
      COALESCE((p_row->>'month_start')::smallint, 1),
      COALESCE((p_row->>'month_end')::smallint, COALESCE((p_row->>'month_start')::smallint, 1)),
      p_row->>'notes'
    )
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object('id', v_id, 'plant_slug', p_row->>'plant_slug', 'activity', p_row->>'activity');
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_patch_garden_species(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_garden_species(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_garden_cultivar(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_plant_care(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_upsert_plant_calendar(jsonb) TO authenticated;

SELECT 'garden-v4-12-content-admin-rpcs ready' AS status;
-- ########## END: garden-v4-12-content-admin-rpcs.sql ##########
