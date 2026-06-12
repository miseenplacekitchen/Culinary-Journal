-- =============================================================================
-- GARDEN v3 POLISH — run on live after RUN-GARDEN-V3.sql
-- RPC fixes + tomato hinge repair. Safe to re-run.
-- =============================================================================

-- garden-v3-06-rpcs.sql
-- Platform Data Model v3 — §10 seasonal engine + browse RPCs.

-- Month in range (handles wrap e.g. harvest Dec–Apr)
CREATE OR REPLACE FUNCTION public.garden_month_in_range(
  p_month smallint, p_start smallint, p_end smallint
)
RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_start IS NULL OR p_end IS NULL THEN false
    WHEN p_start <= p_end THEN p_month BETWEEN p_start AND p_end
    ELSE p_month >= p_start OR p_month <= p_end
  END;
$$;

-- Published plants directory
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
      'id', p.id,
      'slug', p.slug,
      'common_name', p.common_name,
      'botanical_name', p.botanical_name,
      'care_summary', p.care_summary,
      'plant_family', p.plant_family,
      'ease_rating', er.name
    )
    FROM public.plants p
    LEFT JOIN public.ease_ratings er ON er.id = p.ease_rating_id
    WHERE p.is_published = true
      AND (p_search IS NULL OR p_search = ''
           OR p.common_name ILIKE '%' || p_search || '%'
           OR p.botanical_name ILIKE '%' || p_search || '%'
           OR p.slug ILIKE '%' || p_search || '%')
    ORDER BY p.common_name
    LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_published_plants(text, integer, integer) TO anon, authenticated;

-- Plant detail by slug
DROP FUNCTION IF EXISTS public.get_plant_by_slug(text);
CREATE OR REPLACE FUNCTION public.get_plant_by_slug(p_slug text)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v json;
BEGIN
  SELECT id INTO v_id FROM public.plants WHERE slug = p_slug AND is_published = true LIMIT 1;
  IF v_id IS NULL THEN RETURN NULL; END IF;
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
    ), '[]'::json),
    'climate_care', COALESCE((
      SELECT json_agg(json_build_object(
        'field_key', cc.field_key, 'core', cc.core, 'risk', cc.risk, 'fix', cc.fix,
        'climate_zone', cz.name
      ) ORDER BY cc.field_key)
      FROM public.plant_climate_care cc
      LEFT JOIN public.climate_zones cz ON cz.id = cc.climate_zone_id
      WHERE cc.plant_id = v_id
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
GRANT EXECUTE ON FUNCTION public.get_plant_by_slug(text) TO anon, authenticated;

-- §10 "What now, here?" — seasonal activities for user's garden
DROP FUNCTION IF EXISTS public.garden_what_now(smallint);
DROP FUNCTION IF EXISTS public.garden_what_now(integer);
CREATE OR REPLACE FUNCTION public.garden_what_now(p_month smallint DEFAULT NULL)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE
  v_month smallint;
  v_zone uuid;
  v_climate uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v_month := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::smallint);
  SELECT ur.region_id INTO v_zone
    FROM public.user_regions ur WHERE ur.user_id = auth.uid() LIMIT 1;
  SELECT r.climate_zone_id INTO v_climate FROM public.regions r WHERE r.id = v_zone;
  RETURN QUERY
    SELECT json_build_object(
      'plant_slug', p.slug,
      'plant_name', p.common_name,
      'activity', pc.activity,
      'month_start', pc.month_start,
      'month_end', pc.month_end,
      'notes', pc.notes,
      'user_status', up.status,
      'bed_label', up.bed_label
    )
    FROM public.user_plants up
    JOIN public.plants p ON p.id = up.plant_id AND p.is_published = true
    JOIN public.plant_calendar pc ON pc.plant_id = p.id
    WHERE up.user_id = auth.uid()
      AND up.status IN ('planned','growing','harvesting')
      AND public.garden_month_in_range(v_month, pc.month_start, pc.month_end)
      AND (pc.climate_zone_id IS NULL OR v_climate IS NULL OR pc.climate_zone_id = v_climate)
    ORDER BY pc.activity, p.common_name;
END;
$$;
GRANT EXECUTE ON FUNCTION public.garden_what_now(smallint) TO authenticated;

-- Upcoming tasks when nothing this month (next 3 calendar hits)
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
  SELECT r.climate_zone_id INTO v_climate
    FROM public.user_regions ur
    JOIN public.regions r ON r.id = ur.region_id
    WHERE ur.user_id = auth.uid() LIMIT 1;
  RETURN QUERY
    SELECT json_build_object(
      'plant_slug', p.slug,
      'plant_name', p.common_name,
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

-- User garden CRUD helpers
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
      'care_summary', p.care_summary
    )
    FROM public.user_plants up
    JOIN public.plants p ON p.id = up.plant_id
    WHERE up.user_id = auth.uid()
    ORDER BY up.updated_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_garden_plants() TO authenticated;

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
    'region_slug', r.slug,
    'region_name', r.name,
    'climate_zone_id', r.climate_zone_id,
    'climate_zone', cz.name
  ) INTO v
  FROM public.user_regions ur
  JOIN public.regions r ON r.id = ur.region_id
  LEFT JOIN public.climate_zones cz ON cz.id = r.climate_zone_id
  WHERE ur.user_id = auth.uid()
  LIMIT 1;
  RETURN v;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_garden_region() TO authenticated;

DROP FUNCTION IF EXISTS public.upsert_my_garden_plant(uuid, text, date, text, text);
CREATE OR REPLACE FUNCTION public.upsert_my_garden_plant(
  p_plant_id uuid,
  p_status text DEFAULT 'planned',
  p_planted_at date DEFAULT NULL,
  p_bed_label text DEFAULT NULL,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.user_plants (user_id, plant_id, status, planted_at, bed_label, notes)
  VALUES (auth.uid(), p_plant_id, COALESCE(p_status, 'planned'), p_planted_at, p_bed_label, p_notes)
  ON CONFLICT (user_id, plant_id) DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    SELECT id INTO v_id FROM public.user_plants
    WHERE user_id = auth.uid() AND plant_id = p_plant_id LIMIT 1;
    UPDATE public.user_plants SET
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
GRANT EXECUTE ON FUNCTION public.upsert_my_garden_plant(uuid, text, date, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.set_my_garden_region(uuid);
CREATE OR REPLACE FUNCTION public.set_my_garden_region(p_region_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  INSERT INTO public.user_regions (user_id, region_id)
  VALUES (auth.uid(), p_region_id)
  ON CONFLICT (user_id) DO UPDATE SET region_id = EXCLUDED.region_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_my_garden_region(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'garden-v3-06-rpcs ready' AS status;


-- ########## hinge repair ##########

-- fix-garden-v3-polish.sql
-- Live patch AFTER RUN-GARDEN-V3.sql succeeded.
-- Paste garden-v3-06-rpcs.sql first (or this file's companion RUN-GARDEN-V3-POLISH.sql bundle).

-- Re-link tomato hinge via library profile if missing
INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
SELECT p.id, sub.ing_id, 'fruit', true
FROM public.plants p
CROSS JOIN LATERAL (
  SELECT ing_id FROM (
    SELECT lp.governed_ingredient_id AS ing_id, 0 AS pri
    FROM public.library_profiles lp
    WHERE lp.profile_type = 'ingredient' AND lp.slug = 'tomato' AND lp.governed_ingredient_id IS NOT NULL
    UNION ALL
    SELECT i."ID" AS ing_id, 1 AS pri FROM public.ingredients i
    WHERE lower(btrim(i."Ingredient Name")) IN ('tomato', 'tomatoes')
  ) picks ORDER BY pri LIMIT 1
) sub
WHERE p.slug = 'tomato' AND sub.ing_id IS NOT NULL
ON CONFLICT (plant_id, ingredient_id, part) DO NOTHING;

SELECT p.slug, count(pi.id) AS ingredient_links,
  (SELECT lp.slug FROM public.library_profiles lp
   JOIN public.plant_ingredients pi2 ON pi2.ingredient_id = lp.governed_ingredient_id
   WHERE pi2.plant_id = p.id AND lp.profile_type = 'ingredient' LIMIT 1) AS library_slug
FROM public.plants p
LEFT JOIN public.plant_ingredients pi ON pi.plant_id = p.id
WHERE p.slug = 'tomato'
GROUP BY p.id, p.slug;
