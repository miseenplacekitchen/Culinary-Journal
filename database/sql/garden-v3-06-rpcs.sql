-- garden-v3-06-rpcs.sql
-- Platform Data Model v3 — §10 seasonal engine + browse RPCs.

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
    'plant', row_to_json(p.*),
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
    'ingredients', COALESCE((
      SELECT json_agg(json_build_object(
        'ingredient_id', pi.ingredient_id,
        'ingredient_name', i."Ingredient Name",
        'part', pi.part,
        'is_primary', pi.is_primary
      ))
      FROM public.plant_ingredients pi
      JOIN public.ingredients i ON i."ID" = pi.ingredient_id
      WHERE pi.plant_id = v_id
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
  FROM public.plants p WHERE p.id = v_id;
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
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v_month := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::smallint);
  SELECT ur.region_id INTO v_zone
    FROM public.user_regions ur WHERE ur.user_id = auth.uid() LIMIT 1;
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
    LEFT JOIN public.regions r ON r.id = v_zone
    WHERE up.user_id = auth.uid()
      AND up.status IN ('planned','growing','harvesting')
      AND v_month BETWEEN pc.month_start AND pc.month_end
      AND (pc.climate_zone_id IS NULL OR pc.climate_zone_id = r.climate_zone_id OR v_zone IS NULL)
    ORDER BY pc.activity, p.common_name;
END;
$$;
GRANT EXECUTE ON FUNCTION public.garden_what_now(smallint) TO authenticated;

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
