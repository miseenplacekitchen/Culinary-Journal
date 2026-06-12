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
