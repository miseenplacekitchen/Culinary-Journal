-- fix-dish-index-table-ux.sql — Dish Index table UX: visibility column + sync
-- Run after fix-dish-index-intelligence.sql (step 7). Safe to re-run.

ALTER TABLE public.recipe_name_library
  ADD COLUMN IF NOT EXISTS visibility text DEFAULT 'Private';

-- Extend bulk field updates (source_type, visibility, origin) for inline table edits
DROP FUNCTION IF EXISTS public.admin_bulk_update_recipe_name_library(uuid[], jsonb);
CREATE OR REPLACE FUNCTION public.admin_bulk_update_recipe_name_library(
  p_ids uuid[],
  p_fields jsonb
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  v_warnings text[];
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN json_build_object('updated', 0);
  END IF;

  v_warnings := public.rnl_validate_taxonomy(
    p_fields->>'category', p_fields->>'sub_category', p_fields->>'division'
  );
  IF COALESCE((p_fields->>'strict_taxonomy')::boolean, false) AND array_length(v_warnings, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'Taxonomy validation failed: %', array_to_string(v_warnings, '; ');
  END IF;

  UPDATE public.recipe_name_library r SET
    category = CASE WHEN p_fields ? 'category' THEN COALESCE(NULLIF(btrim(p_fields->>'category'), ''), '') ELSE r.category END,
    sub_category = CASE WHEN p_fields ? 'sub_category' THEN COALESCE(NULLIF(btrim(p_fields->>'sub_category'), ''), '') ELSE r.sub_category END,
    division = CASE WHEN p_fields ? 'division' THEN COALESCE(NULLIF(btrim(p_fields->>'division'), ''), '') ELSE r.division END,
    research_status = CASE WHEN p_fields ? 'research_status' THEN COALESCE(NULLIF(btrim(p_fields->>'research_status'), ''), r.research_status) ELSE r.research_status END,
    content_status = CASE WHEN p_fields ? 'content_status' THEN COALESCE(NULLIF(btrim(p_fields->>'content_status'), ''), r.content_status) ELSE r.content_status END,
    source_type = CASE WHEN p_fields ? 'source_type' THEN COALESCE(NULLIF(btrim(p_fields->>'source_type'), ''), 'Original') ELSE r.source_type END,
    visibility = CASE WHEN p_fields ? 'visibility' THEN COALESCE(NULLIF(btrim(p_fields->>'visibility'), ''), 'Private') ELSE r.visibility END,
    origin_continent = CASE WHEN p_fields ? 'origin_continent' THEN COALESCE(NULLIF(btrim(p_fields->>'origin_continent'), ''), '') ELSE r.origin_continent END,
    origin_country = CASE WHEN p_fields ? 'origin_country' THEN COALESCE(NULLIF(btrim(p_fields->>'origin_country'), ''), '') ELSE r.origin_country END,
    origin_state = CASE WHEN p_fields ? 'origin_state' THEN COALESCE(NULLIF(btrim(p_fields->>'origin_state'), ''), '') ELSE r.origin_state END,
    is_active = CASE WHEN p_fields ? 'is_active' THEN COALESCE((p_fields->>'is_active')::boolean, r.is_active) ELSE r.is_active END
  WHERE r.id = ANY(p_ids);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('updated', v_count, 'warnings', COALESCE(v_warnings, '{}'));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_bulk_update_recipe_name_library(uuid[], jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_update_recipe_name_library(uuid[], jsonb) TO authenticated;

-- Push visibility to linked recipe on sync
CREATE OR REPLACE FUNCTION public.admin_sync_recipe_from_name_library(p_id uuid, p_overwrite boolean DEFAULT true)
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
    source_url = NULLIF(r.source_url, ''),
    visibility = COALESCE(NULLIF(r.visibility, ''), sr.visibility, 'Private')
  WHERE sr.id = r.linked_recipe_id;

  RETURN r.linked_recipe_id;
END;
$$;

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
    servings_unit = COALESCE(sr.servings_unit, servings_unit),
    dietary_tags = COALESCE(sr.dietary_tags, dietary_tags),
    health_tags = COALESCE(sr.health_tags, health_tags),
    meal_type_tags = COALESCE(sr.meal_type_tags, meal_type_tags),
    occasion_tags = COALESCE(sr.occasion_tags, occasion_tags),
    style_tags = COALESCE(sr.style_tags, style_tags),
    flavor_profile_tags = COALESCE(sr.flavor_profile_tags, flavor_profile_tags),
    introduction = COALESCE(sr.introduction, ''),
    description = COALESCE(sr.description, ''),
    image_url = COALESCE(sr.image_url, ''),
    image_source_url = COALESCE(sr.image_source_url, ''),
    cooking_notes = COALESCE(sr.cooking_notes, ''),
    cooking_style = COALESCE(sr.cooking_style, ''),
    equipment = v_equipment,
    source_type = COALESCE(sr.source_type, 'Original'),
    credit_name = COALESCE(sr.credit_name, ''),
    credit_handle = COALESCE(sr.credit_handle, ''),
    credit_url = COALESCE(sr.credit_url, ''),
    source_url = COALESCE(sr.source_url, ''),
    visibility = COALESCE(sr.visibility, visibility, 'Private')
  WHERE id = p_id;

  RETURN p_id;
END;
$$;

-- Persist visibility through row upsert (editor + inline table saves).
-- Read visibility from p_row directly — avoids changing rnl_apply_row_fields return type.
CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_name_library(p_row jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_recipe_id uuid;
  v record;
  v_warnings text[];
  v_strict boolean;
  v_dish_code text;
  v_visibility text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NULLIF(btrim(p_row->>'recipe_name'), '') IS NULL THEN
    RAISE EXCEPTION 'Recipe name is required';
  END IF;

  v_visibility := COALESCE(NULLIF(btrim(p_row->>'visibility'), ''), 'Private');
  v_strict := COALESCE((p_row->>'strict_taxonomy')::boolean, false);
  SELECT * INTO v FROM public.rnl_apply_row_fields(p_row);

  v_warnings := public.rnl_validate_taxonomy(v.category, v.sub_category, v.division);
  IF v_strict AND array_length(v_warnings, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'Taxonomy validation failed: %', array_to_string(v_warnings, '; ');
  END IF;

  IF NULLIF(p_row->>'id', '') IS NOT NULL THEN
    v_id := (p_row->>'id')::uuid;
  END IF;
  IF NULLIF(p_row->>'linked_recipe_id', '') IS NOT NULL THEN
    v_recipe_id := (p_row->>'linked_recipe_id')::uuid;
  END IF;

  IF v_id IS NULL AND NULLIF(btrim(COALESCE(p_row->>'dish_code', p_row->>'Dish Code', '')), '') IS NOT NULL THEN
    SELECT id INTO v_id FROM public.recipe_name_library
     WHERE dish_code = btrim(COALESCE(p_row->>'dish_code', p_row->>'Dish Code'))
     LIMIT 1;
  END IF;

  IF v_id IS NULL THEN
    SELECT id INTO v_id
      FROM public.recipe_name_library
     WHERE lower(btrim(recipe_name)) = lower(btrim(v.recipe_name))
       AND COALESCE(NULLIF(btrim(origin_country), ''), '') = COALESCE(NULLIF(btrim(v.origin_country), ''), '')
       AND COALESCE(is_active, true) = true
     LIMIT 1;
  END IF;

  v_dish_code := NULLIF(btrim(COALESCE(p_row->>'dish_code', p_row->>'Dish Code', '')), '');

  IF v_id IS NULL THEN
    IF v_dish_code IS NULL THEN
      v_dish_code := public.rnl_next_dish_code();
    END IF;
    INSERT INTO public.recipe_name_library (
      dish_code, recipe_name, native_name, alternate_names,
      category, sub_category, division,
      origin_continent, origin_country, origin_state, origin_locality,
      primary_ingredients, dietary_tags, meal_type_tags, occasion_tags, style_tags,
      health_tags, flavor_profile_tags, equipment,
      introduction, description, image_url, image_source_url,
      prep_time_minutes, cook_time_minutes, additional_time_minutes,
      servings, servings_unit, difficulty, spice_level, sweet_level, cooking_style,
      cooking_notes, shelf_life_value, shelf_life_unit, shelf_life_storage,
      after_open_value, after_open_unit,
      source_type, credit_name, credit_handle, credit_url, source_url, source_notes,
      research_status, content_status, linked_recipe_id, notes, visibility, is_active, schema_version
    ) VALUES (
      v_dish_code, v.recipe_name, v.native_name, v.alternate_names,
      v.category, v.sub_category, v.division,
      v.origin_continent, v.origin_country, v.origin_state, v.origin_locality,
      v.primary_ingredients, v.dietary_tags, v.meal_type_tags, v.occasion_tags, v.style_tags,
      v.health_tags, v.flavor_profile_tags, v.equipment,
      v.introduction, v.description, v.image_url, v.image_source_url,
      v.prep_time_minutes, v.cook_time_minutes, v.additional_time_minutes,
      v.servings, v.servings_unit, v.difficulty, v.spice_level, v.sweet_level, v.cooking_style,
      v.cooking_notes, v.shelf_life_value, v.shelf_life_unit, v.shelf_life_storage,
      v.after_open_value, v.after_open_unit,
      v.source_type, v.credit_name, v.credit_handle, v.credit_url, v.source_url, v.source_notes,
      v.research_status, v.content_status, v_recipe_id, v.notes, v_visibility,
      COALESCE((p_row->>'is_active')::boolean, true), COALESCE(NULLIF(btrim(p_row->>'schema_version'), ''), '20260702')
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_name_library SET
      dish_code = COALESCE(v_dish_code, dish_code),
      recipe_name = v.recipe_name,
      native_name = v.native_name,
      alternate_names = v.alternate_names,
      category = v.category,
      sub_category = v.sub_category,
      division = v.division,
      origin_continent = v.origin_continent,
      origin_country = v.origin_country,
      origin_state = v.origin_state,
      origin_locality = v.origin_locality,
      primary_ingredients = v.primary_ingredients,
      dietary_tags = v.dietary_tags,
      meal_type_tags = v.meal_type_tags,
      occasion_tags = v.occasion_tags,
      style_tags = v.style_tags,
      health_tags = v.health_tags,
      flavor_profile_tags = v.flavor_profile_tags,
      equipment = v.equipment,
      introduction = v.introduction,
      description = v.description,
      image_url = v.image_url,
      image_source_url = v.image_source_url,
      prep_time_minutes = v.prep_time_minutes,
      cook_time_minutes = v.cook_time_minutes,
      additional_time_minutes = v.additional_time_minutes,
      servings = v.servings,
      servings_unit = v.servings_unit,
      difficulty = v.difficulty,
      spice_level = v.spice_level,
      sweet_level = v.sweet_level,
      cooking_style = v.cooking_style,
      cooking_notes = v.cooking_notes,
      shelf_life_value = v.shelf_life_value,
      shelf_life_unit = v.shelf_life_unit,
      shelf_life_storage = v.shelf_life_storage,
      after_open_value = v.after_open_value,
      after_open_unit = v.after_open_unit,
      source_type = v.source_type,
      credit_name = v.credit_name,
      credit_handle = v.credit_handle,
      credit_url = v.credit_url,
      source_url = v.source_url,
      source_notes = v.source_notes,
      research_status = v.research_status,
      content_status = v.content_status,
      linked_recipe_id = COALESCE(v_recipe_id, linked_recipe_id),
      notes = v.notes,
      visibility = CASE WHEN p_row ? 'visibility' THEN v_visibility ELSE visibility END,
      is_active = COALESCE((p_row->>'is_active')::boolean, is_active),
      schema_version = COALESCE(NULLIF(btrim(p_row->>'schema_version'), ''), schema_version)
    WHERE id = v_id
    RETURNING id INTO v_id;

    UPDATE public.recipe_name_library SET dish_code = public.rnl_next_dish_code()
     WHERE id = v_id AND (dish_code IS NULL OR btrim(dish_code) = '');
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');

SELECT 'fix-dish-index-table-ux complete' AS status;
