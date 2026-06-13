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
