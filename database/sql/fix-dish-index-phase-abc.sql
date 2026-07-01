-- fix-dish-index-phase-abc.sql — Full drift/sync, image_source_url, unarchive, queue counts.
-- Run once in Supabase SQL Editor after fix-dish-index-ops.sql. Safe to re-run.
-- REPLACES fix-dish-index-list-filter.sql (skip list-filter if you run this file).
-- If "Failed to fetch (api.supabase.com)": dashboard network error — run the 3 smaller files instead:
--   fix-dish-index-phase-abc-a.sql  then  -b.sql  then  -c.sql

ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS image_source_url text DEFAULT '';

CREATE OR REPLACE FUNCTION public.rnl_sr_equipment_text(p_sr public.submitted_recipes)
RETURNS text[]
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT COALESCE((
    SELECT array_agg(x #>> '{}')
      FROM jsonb_array_elements(COALESCE(p_sr.equipment, '[]'::jsonb)) AS x
  ), '{}'::text[]);
$$;

CREATE OR REPLACE FUNCTION public.rnl_collect_drift_fields(
  p_rnl public.recipe_name_library,
  p_sr public.submitted_recipes
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public
AS $$
DECLARE
  v_fields jsonb := '[]'::jsonb;
  v_eq text[];
BEGIN
  v_eq := public.rnl_sr_equipment_text(p_sr);

  IF lower(btrim(COALESCE(p_rnl.recipe_name, ''))) IS DISTINCT FROM lower(btrim(COALESCE(p_sr.recipe_name, ''))) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'recipe_name', 'index', p_rnl.recipe_name, 'recipe', p_sr.recipe_name));
  END IF;
  IF lower(btrim(COALESCE(p_rnl.native_name, ''))) IS DISTINCT FROM lower(btrim(COALESCE(p_sr.native_title, ''))) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'native_name', 'index', p_rnl.native_name, 'recipe', p_sr.native_title));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.category), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.category), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'category', 'index', p_rnl.category, 'recipe', p_sr.category));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.sub_category), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.sub_category), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'sub_category', 'index', p_rnl.sub_category, 'recipe', p_sr.sub_category));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.division), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.division), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'division', 'index', p_rnl.division, 'recipe', p_sr.division));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.origin_continent), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.origin_continent), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'origin_continent', 'index', p_rnl.origin_continent, 'recipe', p_sr.origin_continent));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.origin_country), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.origin_country), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'origin_country', 'index', p_rnl.origin_country, 'recipe', p_sr.origin_country));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.origin_state), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.origin_state), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'origin_state', 'index', p_rnl.origin_state, 'recipe', p_sr.origin_state));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.origin_locality), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.origin_locality), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'origin_locality', 'index', p_rnl.origin_locality, 'recipe', p_sr.origin_locality));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.spice_level), ''), 'Not Applicable') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.spice_level), ''), 'Not Applicable') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'spice_level', 'index', p_rnl.spice_level, 'recipe', p_sr.spice_level));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.sweet_level), ''), 'Not Applicable') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.sweet_level), ''), 'Not Applicable') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'sweet_level', 'index', p_rnl.sweet_level, 'recipe', p_sr.sweet_level));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.difficulty), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.difficulty), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'difficulty', 'index', p_rnl.difficulty, 'recipe', p_sr.difficulty));
  END IF;
  IF COALESCE(p_rnl.prep_time_minutes, 0) IS DISTINCT FROM COALESCE(p_sr.prep_time_minutes, 0) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'prep_time_minutes', 'index', p_rnl.prep_time_minutes::text, 'recipe', p_sr.prep_time_minutes::text));
  END IF;
  IF COALESCE(p_rnl.cook_time_minutes, 0) IS DISTINCT FROM COALESCE(p_sr.cook_time_minutes, 0) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'cook_time_minutes', 'index', p_rnl.cook_time_minutes::text, 'recipe', p_sr.cook_time_minutes::text));
  END IF;
  IF COALESCE(p_rnl.additional_time_minutes, 0) IS DISTINCT FROM COALESCE(p_sr.additional_time_minutes, 0) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'additional_time_minutes', 'index', p_rnl.additional_time_minutes::text, 'recipe', p_sr.additional_time_minutes::text));
  END IF;
  IF COALESCE(p_rnl.servings, 0) IS DISTINCT FROM COALESCE(p_sr.servings, 0) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'servings', 'index', p_rnl.servings::text, 'recipe', p_sr.servings::text));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.servings_unit), ''), 'people') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.servings_unit), ''), 'people') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'servings_unit', 'index', p_rnl.servings_unit, 'recipe', p_sr.servings_unit));
  END IF;
  IF COALESCE(p_rnl.dietary_tags, '{}') IS DISTINCT FROM COALESCE(p_sr.dietary_tags, '{}') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'dietary_tags', 'index', array_to_string(p_rnl.dietary_tags, '; '), 'recipe', array_to_string(p_sr.dietary_tags, '; ')));
  END IF;
  IF COALESCE(p_rnl.health_tags, '{}') IS DISTINCT FROM COALESCE(p_sr.health_tags, '{}') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'health_tags', 'index', array_to_string(p_rnl.health_tags, '; '), 'recipe', array_to_string(p_sr.health_tags, '; ')));
  END IF;
  IF COALESCE(p_rnl.meal_type_tags, '{}') IS DISTINCT FROM COALESCE(p_sr.meal_type_tags, '{}') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'meal_type_tags', 'index', array_to_string(p_rnl.meal_type_tags, '; '), 'recipe', array_to_string(p_sr.meal_type_tags, '; ')));
  END IF;
  IF COALESCE(p_rnl.occasion_tags, '{}') IS DISTINCT FROM COALESCE(p_sr.occasion_tags, '{}') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'occasion_tags', 'index', array_to_string(p_rnl.occasion_tags, '; '), 'recipe', array_to_string(p_sr.occasion_tags, '; ')));
  END IF;
  IF COALESCE(p_rnl.style_tags, '{}') IS DISTINCT FROM COALESCE(p_sr.style_tags, '{}') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'style_tags', 'index', array_to_string(p_rnl.style_tags, '; '), 'recipe', array_to_string(p_sr.style_tags, '; ')));
  END IF;
  IF COALESCE(p_rnl.flavor_profile_tags, '{}') IS DISTINCT FROM COALESCE(p_sr.flavor_profile_tags, '{}') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'flavor_profile_tags', 'index', array_to_string(p_rnl.flavor_profile_tags, '; '), 'recipe', array_to_string(p_sr.flavor_profile_tags, '; ')));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.introduction), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.introduction), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'introduction', 'index', left(p_rnl.introduction, 120), 'recipe', left(p_sr.introduction, 120)));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.description), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.description), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'description', 'index', left(p_rnl.description, 120), 'recipe', left(p_sr.description, 120)));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.image_url), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.image_url), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'image_url', 'index', p_rnl.image_url, 'recipe', p_sr.image_url));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.image_source_url), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.image_source_url), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'image_source_url', 'index', p_rnl.image_source_url, 'recipe', p_sr.image_source_url));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.cooking_notes), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.cooking_notes), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'cooking_notes', 'index', left(p_rnl.cooking_notes, 120), 'recipe', left(p_sr.cooking_notes, 120)));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.cooking_style), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.cooking_style), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'cooking_style', 'index', p_rnl.cooking_style, 'recipe', p_sr.cooking_style));
  END IF;
  IF COALESCE(p_rnl.equipment, '{}') IS DISTINCT FROM v_eq THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'equipment', 'index', array_to_string(p_rnl.equipment, '; '), 'recipe', array_to_string(v_eq, '; ')));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.shelf_life_value), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.shelf_life_value), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'shelf_life_value', 'index', p_rnl.shelf_life_value, 'recipe', p_sr.shelf_life_value));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.shelf_life_unit), ''), 'months') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.shelf_life_unit), ''), 'months') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'shelf_life_unit', 'index', p_rnl.shelf_life_unit, 'recipe', p_sr.shelf_life_unit));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.shelf_life_storage), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.shelf_life_storage), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'shelf_life_storage', 'index', p_rnl.shelf_life_storage, 'recipe', p_sr.shelf_life_storage));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.after_open_value), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.after_open_value), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'after_open_value', 'index', p_rnl.after_open_value, 'recipe', p_sr.after_open_value));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.after_open_unit), ''), 'weeks') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.after_open_unit), ''), 'weeks') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'after_open_unit', 'index', p_rnl.after_open_unit, 'recipe', p_sr.after_open_unit));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.source_type), ''), 'Original') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.source_type), ''), 'Original') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'source_type', 'index', p_rnl.source_type, 'recipe', p_sr.source_type));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.credit_name), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.credit_name), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'credit_name', 'index', p_rnl.credit_name, 'recipe', p_sr.credit_name));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.credit_handle), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.credit_handle), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'credit_handle', 'index', p_rnl.credit_handle, 'recipe', p_sr.credit_handle));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.credit_url), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.credit_url), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'credit_url', 'index', p_rnl.credit_url, 'recipe', p_sr.credit_url));
  END IF;
  IF COALESCE(NULLIF(btrim(p_rnl.source_url), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.source_url), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'source_url', 'index', p_rnl.source_url, 'recipe', p_sr.source_url));
  END IF;

  RETURN v_fields;
END;
$$;

CREATE OR REPLACE FUNCTION public.rnl_has_drift(p_rnl public.recipe_name_library, p_sr public.submitted_recipes)
RETURNS boolean
LANGUAGE sql STABLE SET search_path = public
AS $$
  SELECT jsonb_array_length(public.rnl_collect_drift_fields(p_rnl, p_sr)) > 0;
$$;

DROP FUNCTION IF EXISTS public.admin_name_library_drift(uuid);
CREATE OR REPLACE FUNCTION public.admin_name_library_drift(p_id uuid)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rnl public.recipe_name_library%ROWTYPE;
  v_sr public.submitted_recipes%ROWTYPE;
  v_fields jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT * INTO v_rnl FROM public.recipe_name_library WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dish index row not found'; END IF;
  IF v_rnl.linked_recipe_id IS NULL THEN
    RETURN json_build_object('has_drift', false, 'fields', '[]'::json);
  END IF;
  SELECT * INTO v_sr FROM public.submitted_recipes WHERE id = v_rnl.linked_recipe_id;
  IF NOT FOUND THEN
    RETURN json_build_object('has_drift', true, 'fields', json_build_array(jsonb_build_object('field', 'linked_recipe_id', 'index', v_rnl.linked_recipe_id::text, 'recipe', 'missing')));
  END IF;
  v_fields := public.rnl_collect_drift_fields(v_rnl, v_sr);
  RETURN json_build_object('has_drift', jsonb_array_length(v_fields) > 0, 'fields', v_fields);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_name_library_drift(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_name_library_drift(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_sync_recipe_from_name_library(uuid, boolean);
CREATE OR REPLACE FUNCTION public.admin_sync_recipe_from_name_library(
  p_id uuid,
  p_overwrite boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r public.recipe_name_library%ROWTYPE;
  v_equipment jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT * INTO r FROM public.recipe_name_library WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dish index row not found'; END IF;
  IF r.linked_recipe_id IS NULL THEN RAISE EXCEPTION 'No linked recipe to sync'; END IF;

  v_equipment := COALESCE(
    (SELECT jsonb_agg(to_jsonb(x)) FROM unnest(COALESCE(r.equipment, '{}')) AS x),
    '[]'::jsonb
  );

  UPDATE public.submitted_recipes sr SET
    recipe_name = r.recipe_name,
    native_title = COALESCE(r.native_name, ''),
    category = NULLIF(r.category, ''),
    sub_category = NULLIF(r.sub_category, ''),
    division = NULLIF(r.division, ''),
    origin_continent = NULLIF(r.origin_continent, ''),
    origin_country = NULLIF(r.origin_country, ''),
    origin_state = NULLIF(r.origin_state, ''),
    origin_locality = NULLIF(r.origin_locality, ''),
    spice_level = COALESCE(NULLIF(r.spice_level, ''), sr.spice_level),
    sweet_level = COALESCE(NULLIF(r.sweet_level, ''), sr.sweet_level),
    difficulty = NULLIF(r.difficulty, ''),
    prep_time_minutes = COALESCE(r.prep_time_minutes, 0),
    cook_time_minutes = COALESCE(r.cook_time_minutes, 0),
    additional_time_minutes = COALESCE(r.additional_time_minutes, 0),
    servings = GREATEST(COALESCE(r.servings, 0), 1),
    servings_unit = COALESCE(NULLIF(r.servings_unit, ''), 'people'),
    dietary_tags = COALESCE(r.dietary_tags, '{}'),
    health_tags = COALESCE(r.health_tags, '{}'),
    meal_type_tags = COALESCE(r.meal_type_tags, '{}'),
    occasion_tags = COALESCE(r.occasion_tags, '{}'),
    style_tags = COALESCE(r.style_tags, '{}'),
    flavor_profile_tags = COALESCE(r.flavor_profile_tags, '{}'),
    introduction = COALESCE(r.introduction, ''),
    description = COALESCE(r.description, ''),
    image_url = COALESCE(r.image_url, ''),
    image_source_url = COALESCE(r.image_source_url, ''),
    cooking_notes = COALESCE(r.cooking_notes, ''),
    cooking_style = NULLIF(r.cooking_style, ''),
    equipment = v_equipment,
    shelf_life_value = NULLIF(r.shelf_life_value, ''),
    shelf_life_unit = COALESCE(NULLIF(r.shelf_life_unit, ''), 'months'),
    shelf_life_storage = NULLIF(r.shelf_life_storage, ''),
    after_open_value = NULLIF(r.after_open_value, ''),
    after_open_unit = COALESCE(NULLIF(r.after_open_unit, ''), 'weeks'),
    source_type = COALESCE(NULLIF(r.source_type, ''), 'Original'),
    credit_name = NULLIF(r.credit_name, ''),
    credit_handle = NULLIF(r.credit_handle, ''),
    credit_url = NULLIF(r.credit_url, ''),
    source_url = NULLIF(r.source_url, '')
  WHERE sr.id = r.linked_recipe_id;

  RETURN r.linked_recipe_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_sync_recipe_from_name_library(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_sync_recipe_from_name_library(uuid, boolean) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_sync_name_library_from_recipe(uuid);
CREATE OR REPLACE FUNCTION public.admin_sync_name_library_from_recipe(p_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r public.recipe_name_library%ROWTYPE;
  sr public.submitted_recipes%ROWTYPE;
  v_equipment text[];
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT * INTO r FROM public.recipe_name_library WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dish index row not found'; END IF;
  IF r.linked_recipe_id IS NULL THEN RAISE EXCEPTION 'No linked recipe to sync from'; END IF;
  SELECT * INTO sr FROM public.submitted_recipes WHERE id = r.linked_recipe_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Linked recipe not found'; END IF;

  v_equipment := public.rnl_sr_equipment_text(sr);

  UPDATE public.recipe_name_library SET
    recipe_name = sr.recipe_name,
    native_name = COALESCE(sr.native_title, ''),
    category = COALESCE(sr.category, ''),
    sub_category = COALESCE(sr.sub_category, ''),
    division = COALESCE(sr.division, ''),
    origin_continent = COALESCE(sr.origin_continent, ''),
    origin_country = COALESCE(sr.origin_country, ''),
    origin_state = COALESCE(sr.origin_state, ''),
    origin_locality = COALESCE(sr.origin_locality, ''),
    spice_level = COALESCE(sr.spice_level, spice_level),
    sweet_level = COALESCE(sr.sweet_level, sweet_level),
    difficulty = COALESCE(sr.difficulty, ''),
    prep_time_minutes = COALESCE(sr.prep_time_minutes, 0),
    cook_time_minutes = COALESCE(sr.cook_time_minutes, 0),
    additional_time_minutes = COALESCE(sr.additional_time_minutes, 0),
    servings = COALESCE(sr.servings, 0),
    servings_unit = COALESCE(sr.servings_unit, 'people'),
    dietary_tags = COALESCE(sr.dietary_tags, '{}'),
    health_tags = COALESCE(sr.health_tags, '{}'),
    meal_type_tags = COALESCE(sr.meal_type_tags, '{}'),
    occasion_tags = COALESCE(sr.occasion_tags, '{}'),
    style_tags = COALESCE(sr.style_tags, '{}'),
    flavor_profile_tags = COALESCE(sr.flavor_profile_tags, '{}'),
    introduction = COALESCE(sr.introduction, ''),
    description = COALESCE(sr.description, ''),
    image_url = COALESCE(sr.image_url, ''),
    image_source_url = COALESCE(sr.image_source_url, ''),
    cooking_notes = COALESCE(sr.cooking_notes, ''),
    cooking_style = COALESCE(sr.cooking_style, ''),
    equipment = COALESCE(v_equipment, '{}'),
    shelf_life_value = COALESCE(sr.shelf_life_value, ''),
    shelf_life_unit = COALESCE(sr.shelf_life_unit, 'months'),
    shelf_life_storage = COALESCE(sr.shelf_life_storage, ''),
    after_open_value = COALESCE(sr.after_open_value, ''),
    after_open_unit = COALESCE(sr.after_open_unit, 'weeks'),
    source_type = COALESCE(sr.source_type, 'Original'),
    credit_name = COALESCE(sr.credit_name, ''),
    credit_handle = COALESCE(sr.credit_handle, ''),
    credit_url = COALESCE(sr.credit_url, ''),
    source_url = COALESCE(sr.source_url, '')
  WHERE id = p_id;

  RETURN p_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_sync_name_library_from_recipe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_sync_name_library_from_recipe(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_create_recipe_from_name_library(uuid);
CREATE OR REPLACE FUNCTION public.admin_create_recipe_from_name_library(p_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r public.recipe_name_library%ROWTYPE;
  v_recipe_id uuid;
  v_equipment jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT * INTO r FROM public.recipe_name_library WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dish index row not found'; END IF;
  IF r.linked_recipe_id IS NOT NULL THEN RETURN r.linked_recipe_id; END IF;

  v_equipment := COALESCE(
    (SELECT jsonb_agg(to_jsonb(x)) FROM unnest(COALESCE(r.equipment, '{}')) AS x),
    '[]'::jsonb
  );

  INSERT INTO public.submitted_recipes (
    user_id, recipe_name, native_title, category, sub_category, division,
    origin_continent, origin_country, origin_state, origin_locality,
    spice_level, sweet_level, difficulty,
    prep_time_minutes, cook_time_minutes, additional_time_minutes,
    servings, servings_unit,
    dietary_tags, health_tags, meal_type_tags, occasion_tags, style_tags, flavor_profile_tags,
    introduction, description, image_url, image_source_url,
    cooking_notes, cooking_style, equipment,
    shelf_life_value, shelf_life_unit, shelf_life_storage,
    after_open_value, after_open_unit,
    source_type, credit_name, credit_handle, credit_url, source_url,
    ingredients, method, visibility, status, personal_notes
  ) VALUES (
    auth.uid(), r.recipe_name, COALESCE(r.native_name, ''),
    NULLIF(r.category, ''), NULLIF(r.sub_category, ''), NULLIF(r.division, ''),
    NULLIF(r.origin_continent, ''), NULLIF(r.origin_country, ''), NULLIF(r.origin_state, ''), NULLIF(r.origin_locality, ''),
    COALESCE(NULLIF(r.spice_level, ''), 'Not Applicable'),
    COALESCE(NULLIF(r.sweet_level, ''), 'Not Applicable'),
    NULLIF(r.difficulty, ''),
    COALESCE(r.prep_time_minutes, 0), COALESCE(r.cook_time_minutes, 0), COALESCE(r.additional_time_minutes, 0),
    GREATEST(COALESCE(r.servings, 0), 1), COALESCE(NULLIF(r.servings_unit, ''), 'people'),
    COALESCE(r.dietary_tags, '{}'), COALESCE(r.health_tags, '{}'),
    COALESCE(r.meal_type_tags, '{}'), COALESCE(r.occasion_tags, '{}'),
    COALESCE(r.style_tags, '{}'), COALESCE(r.flavor_profile_tags, '{}'),
    COALESCE(r.introduction, ''), COALESCE(r.description, ''), COALESCE(r.image_url, ''), COALESCE(r.image_source_url, ''),
    COALESCE(r.cooking_notes, ''), NULLIF(r.cooking_style, ''), v_equipment,
    NULLIF(r.shelf_life_value, ''), COALESCE(NULLIF(r.shelf_life_unit, ''), 'months'), NULLIF(r.shelf_life_storage, ''),
    NULLIF(r.after_open_value, ''), COALESCE(NULLIF(r.after_open_unit, ''), 'weeks'),
    COALESCE(NULLIF(r.source_type, ''), 'Original'),
    NULLIF(r.credit_name, ''), NULLIF(r.credit_handle, ''), NULLIF(r.credit_url, ''), NULLIF(r.source_url, ''),
    '[]'::jsonb, '[]'::jsonb, 'Private', 'pending',
    COALESCE(r.notes, 'Created from Dish Index')
  )
  RETURNING id INTO v_recipe_id;

  UPDATE public.recipe_name_library
     SET linked_recipe_id = v_recipe_id,
         content_status = 'draft_created'
   WHERE id = p_id;

  RETURN v_recipe_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_create_recipe_from_name_library(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_recipe_from_name_library(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_restore_recipe_name_library(uuid[]);
CREATE OR REPLACE FUNCTION public.admin_restore_recipe_name_library(p_ids uuid[])
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN json_build_object('restored', 0);
  END IF;

  UPDATE public.recipe_name_library SET
    is_active = true,
    content_status = CASE
      WHEN content_status IN ('retired', 'duplicate') THEN 'not_started'
      ELSE content_status
    END
  WHERE id = ANY(p_ids)
    AND COALESCE(is_active, true) = false;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('restored', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_restore_recipe_name_library(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_restore_recipe_name_library(uuid[]) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_dish_index_queue_counts();
CREATE OR REPLACE FUNCTION public.admin_dish_index_queue_counts()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN json_build_object(
    'all', (SELECT count(*)::int FROM public.recipe_name_library WHERE COALESCE(is_active, true)),
    'ready_unlinked', (
      SELECT count(*)::int FROM public.recipe_name_library
       WHERE COALESCE(is_active, true)
         AND research_status = 'ready_to_draft'
         AND linked_recipe_id IS NULL
    ),
    'needs_research', (
      SELECT count(*)::int FROM public.recipe_name_library
       WHERE COALESCE(is_active, true) AND research_status = 'needs_research'
    ),
    'verified_unlinked', (
      SELECT count(*)::int FROM public.recipe_name_library
       WHERE COALESCE(is_active, true)
         AND research_status = 'verified'
         AND linked_recipe_id IS NULL
    ),
    'linked_drift', (
      SELECT count(*)::int
        FROM public.recipe_name_library rnl
        LEFT JOIN public.submitted_recipes sr ON sr.id = rnl.linked_recipe_id
       WHERE COALESCE(rnl.is_active, true)
         AND rnl.linked_recipe_id IS NOT NULL
         AND sr.id IS NOT NULL
         AND public.rnl_has_drift(rnl, sr)
    ),
    'archived', (
      SELECT count(*)::int FROM public.recipe_name_library
       WHERE COALESCE(is_active, true) = false
    )
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_dish_index_queue_counts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dish_index_queue_counts() TO authenticated;

-- Extend list sort columns
DROP FUNCTION IF EXISTS public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text, text, text, boolean, text);
DROP FUNCTION IF EXISTS public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.admin_list_recipe_name_library(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_search text DEFAULT NULL,
  p_research_status text DEFAULT NULL,
  p_content_status text DEFAULT NULL,
  p_linked text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_sort_col text DEFAULT 'recipe_name',
  p_sort_dir text DEFAULT 'asc',
  p_sub_category text DEFAULT NULL,
  p_division text DEFAULT NULL,
  p_active_filter text DEFAULT 'active',
  p_drift text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total bigint;
  v_rows json;
  v_order_col text;
  v_order_dir text;
  v_active text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_active := lower(COALESCE(NULLIF(btrim(p_active_filter), ''), 'active'));
  IF v_active NOT IN ('active', 'archived', 'all') THEN
    v_active := 'active';
  END IF;

  v_order_col := CASE p_sort_col
    WHEN 'dish_code' THEN 'dish_code'
    WHEN 'native_name' THEN 'native_name'
    WHEN 'category' THEN 'category'
    WHEN 'sub_category' THEN 'sub_category'
    WHEN 'division' THEN 'division'
    WHEN 'origin_country' THEN 'origin_country'
    WHEN 'origin_state' THEN 'origin_state'
    WHEN 'primary_ingredients' THEN 'primary_ingredients'
    WHEN 'prep_time_minutes' THEN 'prep_time_minutes'
    WHEN 'servings' THEN 'servings'
    WHEN 'difficulty' THEN 'difficulty'
    WHEN 'spice_level' THEN 'spice_level'
    WHEN 'cooking_style' THEN 'cooking_style'
    WHEN 'research_status' THEN 'research_status'
    WHEN 'content_status' THEN 'content_status'
    WHEN 'updated_at' THEN 'updated_at'
    WHEN 'created_at' THEN 'created_at'
    ELSE 'recipe_name'
  END;
  v_order_dir := CASE WHEN lower(COALESCE(p_sort_dir, 'asc')) = 'desc' THEN 'DESC' ELSE 'ASC' END;

  SELECT count(*) INTO v_total
    FROM public.recipe_name_library rnl
    LEFT JOIN public.submitted_recipes sr ON sr.id = rnl.linked_recipe_id
   WHERE (
          v_active = 'all'
          OR (v_active = 'active' AND COALESCE(rnl.is_active, true) = true)
          OR (v_active = 'archived' AND COALESCE(rnl.is_active, true) = false)
        )
     AND (p_search IS NULL OR btrim(p_search) = ''
          OR rnl.recipe_name ILIKE '%' || p_search || '%'
          OR rnl.native_name ILIKE '%' || p_search || '%'
          OR rnl.origin_country ILIKE '%' || p_search || '%'
          OR rnl.dish_code ILIKE '%' || p_search || '%'
          OR EXISTS (SELECT 1 FROM unnest(COALESCE(rnl.alternate_names, '{}')) a WHERE a ILIKE '%' || p_search || '%'))
     AND (p_research_status IS NULL OR btrim(p_research_status) = '' OR rnl.research_status = p_research_status)
     AND (p_content_status IS NULL OR btrim(p_content_status) = '' OR rnl.content_status = p_content_status)
     AND (p_category IS NULL OR btrim(p_category) = '' OR rnl.category = p_category)
     AND (p_sub_category IS NULL OR btrim(p_sub_category) = '' OR rnl.sub_category = p_sub_category)
     AND (p_division IS NULL OR btrim(p_division) = '' OR rnl.division = p_division)
     AND (p_linked IS NULL OR btrim(p_linked) = ''
          OR (p_linked = 'linked' AND rnl.linked_recipe_id IS NOT NULL)
          OR (p_linked = 'unlinked' AND rnl.linked_recipe_id IS NULL))
     AND (p_drift IS NULL OR btrim(p_drift) = ''
          OR (p_drift = 'yes' AND rnl.linked_recipe_id IS NOT NULL AND public.rnl_has_drift(rnl, sr))
          OR (p_drift = 'no' AND (rnl.linked_recipe_id IS NULL OR NOT public.rnl_has_drift(rnl, sr))));

  EXECUTE format($SQL$
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
      FROM (
        SELECT rnl.*,
               sr.recipe_name AS linked_recipe_name,
               sr.recipe_code AS linked_recipe_code,
               sr.status AS linked_recipe_status,
               CASE WHEN rnl.linked_recipe_id IS NOT NULL AND sr.id IS NOT NULL
                    THEN public.rnl_has_drift(rnl, sr) ELSE false END AS has_drift
          FROM public.recipe_name_library rnl
          LEFT JOIN public.submitted_recipes sr ON sr.id = rnl.linked_recipe_id
         WHERE (
                $8 = 'all'
                OR ($8 = 'active' AND COALESCE(rnl.is_active, true) = true)
                OR ($8 = 'archived' AND COALESCE(rnl.is_active, true) = false)
              )
           AND ($1 IS NULL OR btrim($1) = ''
                OR rnl.recipe_name ILIKE '%%' || $1 || '%%'
                OR rnl.native_name ILIKE '%%' || $1 || '%%'
                OR rnl.origin_country ILIKE '%%' || $1 || '%%'
                OR rnl.dish_code ILIKE '%%' || $1 || '%%'
                OR EXISTS (SELECT 1 FROM unnest(COALESCE(rnl.alternate_names, '{}')) a WHERE a ILIKE '%%' || $1 || '%%'))
           AND ($2 IS NULL OR btrim($2) = '' OR rnl.research_status = $2)
           AND ($3 IS NULL OR btrim($3) = '' OR rnl.content_status = $3)
           AND ($4 IS NULL OR btrim($4) = '' OR rnl.category = $4)
           AND ($9 IS NULL OR btrim($9) = '' OR rnl.sub_category = $9)
           AND ($10 IS NULL OR btrim($10) = '' OR rnl.division = $10)
           AND ($5 IS NULL OR btrim($5) = ''
                OR ($5 = 'linked' AND rnl.linked_recipe_id IS NOT NULL)
                OR ($5 = 'unlinked' AND rnl.linked_recipe_id IS NULL))
           AND ($11 IS NULL OR btrim($11) = ''
                OR ($11 = 'yes' AND rnl.linked_recipe_id IS NOT NULL AND public.rnl_has_drift(rnl, sr))
                OR ($11 = 'no' AND (rnl.linked_recipe_id IS NULL OR NOT public.rnl_has_drift(rnl, sr))))
         ORDER BY rnl.%I %s NULLS LAST, rnl.recipe_name ASC
         LIMIT LEAST(GREATEST(COALESCE($6, 50), 1), 500)
        OFFSET GREATEST(COALESCE($7, 0), 0)
      ) t
  $SQL$, v_order_col, v_order_dir)
  INTO v_rows
  USING p_search, p_research_status, p_content_status, p_category, p_linked,
        p_limit, p_offset, v_active, p_sub_category, p_division, p_drift;

  RETURN json_build_object('total', v_total, 'rows', COALESCE(v_rows, '[]'::json));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text, text, text, text, text) TO authenticated;
