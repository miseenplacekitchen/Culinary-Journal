-- fix-dish-index-phase-abc-a.sql — Part 1/3: drift detection. Run after fix-dish-index-ops.sql.
-- Then run -b.sql, then -c.sql.

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
