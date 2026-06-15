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
  IF v_id IS NULL THEN RAISE EXCEPTION 'plant not found: %', p_slug; END IF;

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
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found'; END IF;

  v_slug := lower(regexp_replace(trim(COALESCE(p_row->>'slug', p_row->>'name', '')), '[^a-z0-9]+', '-', 'g'), '-');

  INSERT INTO plant_varieties (
    plant_id, slug, name, lineage_type, origin, traits, flesh_fruit,
    yield_notes, growing_notes, availability, sort_order, is_published
  ) VALUES (
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
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found'; END IF;

  SELECT id INTO v_climate FROM climate_zones WHERE slug = p_row->>'climate_slug' LIMIT 1;
  IF v_climate IS NULL THEN RAISE EXCEPTION 'climate not found'; END IF;

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
  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant not found'; END IF;

  SELECT id INTO v_climate FROM climate_zones WHERE slug = p_row->>'climate_slug' LIMIT 1;
  IF v_climate IS NULL THEN RAISE EXCEPTION 'climate not found'; END IF;

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
