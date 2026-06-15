-- Admin can save ANY submit-recipe field while reviewing pending imports.
-- Run once in Supabase SQL Editor (recipes pipeline — June 2026).

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'admin_edit_recipe'
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_edit_recipe(
  p_id uuid, p_recipe_name text DEFAULT NULL, p_category text DEFAULT NULL,
  p_spice_level text DEFAULT NULL, p_native_title text DEFAULT NULL,
  p_introduction text DEFAULT NULL, p_cooking_notes text DEFAULT NULL,
  p_servings int DEFAULT NULL,
  p_origin_locality text DEFAULT NULL, p_origin_state text DEFAULT NULL,
  p_origin_country text DEFAULT NULL,
  p_image_url text DEFAULT NULL,
  p_prep_time_minutes int DEFAULT NULL,
  p_cook_time_minutes int DEFAULT NULL,
  p_sweet_level text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes SET
    recipe_name         = COALESCE(NULLIF(btrim(p_recipe_name), ''), recipe_name),
    category            = COALESCE(NULLIF(btrim(p_category), ''), category),
    spice_level         = COALESCE(NULLIF(btrim(p_spice_level), ''), spice_level),
    sweet_level         = COALESCE(NULLIF(btrim(p_sweet_level), ''), sweet_level),
    native_title        = COALESCE(NULLIF(btrim(p_native_title), ''), native_title),
    introduction        = COALESCE(p_introduction, introduction),
    cooking_notes       = COALESCE(p_cooking_notes, cooking_notes),
    servings            = COALESCE(p_servings, servings),
    prep_time_minutes    = COALESCE(p_prep_time_minutes, prep_time_minutes),
    cook_time_minutes    = COALESCE(p_cook_time_minutes, cook_time_minutes),
    origin_locality     = COALESCE(NULLIF(btrim(p_origin_locality), ''), origin_locality),
    origin_state        = COALESCE(NULLIF(btrim(p_origin_state), ''), origin_state),
    origin_country      = COALESCE(NULLIF(btrim(p_origin_country), ''), origin_country),
    image_url           = CASE
                            WHEN p_image_url IS NOT NULL AND btrim(p_image_url) <> '' THEN btrim(p_image_url)
                            ELSE image_url
                          END
  WHERE id = p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_edit_recipe(
  uuid,text,text,text,text,text,text,int,text,text,text,text,int,int,text
) TO authenticated;

-- Full save — same fields as Submit a Recipe (ingredients, method, tags, credits, …)
CREATE OR REPLACE FUNCTION public.admin_save_recipe_review(p_id uuid, p_data jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_int int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_data IS NULL OR p_data = 'null'::jsonb THEN
    RAISE EXCEPTION 'Empty payload';
  END IF;

  v_int := NULLIF(regexp_replace(COALESCE(p_data->>'prep_time_minutes', ''), '\D', '', 'g'), '')::int;

  UPDATE public.submitted_recipes SET
    recipe_name              = COALESCE(NULLIF(btrim(p_data->>'recipe_name'), ''), recipe_name),
    native_title             = COALESCE(p_data->>'native_title', native_title),
    category                 = COALESCE(NULLIF(p_data->>'category', ''), category),
    sub_category             = CASE WHEN p_data ? 'sub_category' THEN NULLIF(p_data->>'sub_category', '') ELSE sub_category END,
    division                 = CASE WHEN p_data ? 'division' THEN NULLIF(p_data->>'division', '') ELSE division END,
    spice_level              = COALESCE(NULLIF(p_data->>'spice_level', ''), spice_level),
    sweet_level              = COALESCE(NULLIF(p_data->>'sweet_level', ''), sweet_level),
    origin_continent         = CASE WHEN p_data ? 'origin_continent' THEN NULLIF(p_data->>'origin_continent', '') ELSE origin_continent END,
    origin_country           = CASE WHEN p_data ? 'origin_country' THEN NULLIF(p_data->>'origin_country', '') ELSE origin_country END,
    origin_state             = CASE WHEN p_data ? 'origin_state' THEN NULLIF(p_data->>'origin_state', '') ELSE origin_state END,
    origin_locality          = CASE WHEN p_data ? 'origin_locality' THEN NULLIF(p_data->>'origin_locality', '') ELSE origin_locality END,
    introduction             = CASE WHEN p_data ? 'introduction' THEN COALESCE(p_data->>'introduction', '') ELSE introduction END,
    cooking_notes            = CASE WHEN p_data ? 'cooking_notes' THEN COALESCE(p_data->>'cooking_notes', '') ELSE cooking_notes END,
    personal_notes           = CASE WHEN p_data ? 'personal_notes' THEN NULLIF(p_data->>'personal_notes', '') ELSE personal_notes END,
    prep_time_minutes        = CASE WHEN p_data ? 'prep_time_minutes' THEN COALESCE(NULLIF(regexp_replace(COALESCE(p_data->>'prep_time_minutes', ''), '\D', '', 'g'), '')::int, 0) ELSE COALESCE(prep_time_minutes::int, 0) END,
    cook_time_minutes        = CASE WHEN p_data ? 'cook_time_minutes' THEN COALESCE(NULLIF(regexp_replace(COALESCE(p_data->>'cook_time_minutes', ''), '\D', '', 'g'), '')::int, 0) ELSE COALESCE(cook_time_minutes::int, 0) END,
    additional_time_minutes  = CASE WHEN p_data ? 'additional_time_minutes' THEN COALESCE(NULLIF(regexp_replace(COALESCE(p_data->>'additional_time_minutes', ''), '\D', '', 'g'), '')::int, 0) ELSE COALESCE(additional_time_minutes::int, 0) END,
    servings                 = CASE WHEN p_data ? 'servings' THEN GREATEST(COALESCE(NULLIF(regexp_replace(COALESCE(p_data->>'servings', ''), '\D', '', 'g'), '')::int, 1), 1) ELSE COALESCE(servings::int, 1) END,
    servings_unit            = CASE WHEN p_data ? 'servings_unit' THEN COALESCE(NULLIF(p_data->>'servings_unit', ''), servings_unit) ELSE servings_unit END,
    difficulty               = CASE WHEN p_data ? 'difficulty' THEN COALESCE(p_data->>'difficulty', '') ELSE difficulty END,
    source_type              = CASE WHEN p_data ? 'source_type' THEN COALESCE(NULLIF(p_data->>'source_type', ''), source_type) ELSE source_type END,
    credit_name              = CASE WHEN p_data ? 'credit_name' THEN NULLIF(p_data->>'credit_name', '') ELSE credit_name END,
    credit_handle            = CASE WHEN p_data ? 'credit_handle' THEN NULLIF(p_data->>'credit_handle', '') ELSE credit_handle END,
    credit_url               = CASE WHEN p_data ? 'credit_url' THEN NULLIF(p_data->>'credit_url', '') ELSE credit_url END,
    visibility               = CASE WHEN p_data ? 'visibility' THEN COALESCE(NULLIF(p_data->>'visibility', ''), visibility) ELSE visibility END,
    cooking_style            = CASE WHEN p_data ? 'cooking_style' THEN NULLIF(p_data->>'cooking_style', '') ELSE cooking_style END,
    shelf_life_value         = CASE WHEN p_data ? 'shelf_life_value' THEN NULLIF(p_data->>'shelf_life_value', '') ELSE shelf_life_value END,
    shelf_life_unit          = CASE WHEN p_data ? 'shelf_life_unit' THEN COALESCE(p_data->>'shelf_life_unit', shelf_life_unit) ELSE shelf_life_unit END,
    shelf_life_storage       = CASE WHEN p_data ? 'shelf_life_storage' THEN NULLIF(p_data->>'shelf_life_storage', '') ELSE shelf_life_storage END,
    after_open_value         = CASE WHEN p_data ? 'after_open_value' THEN NULLIF(p_data->>'after_open_value', '') ELSE after_open_value END,
    after_open_unit          = CASE WHEN p_data ? 'after_open_unit' THEN COALESCE(p_data->>'after_open_unit', after_open_unit) ELSE after_open_unit END,
    image_url                = CASE WHEN p_data ? 'image_url' AND NULLIF(btrim(p_data->>'image_url'), '') IS NOT NULL THEN btrim(p_data->>'image_url') ELSE image_url END,
    ingredients              = CASE WHEN p_data ? 'ingredients' THEN p_data->'ingredients' ELSE ingredients END,
    method                   = CASE WHEN p_data ? 'method' THEN p_data->'method' ELSE method END,
    equipment                = CASE WHEN p_data ? 'equipment' THEN p_data->'equipment' ELSE equipment END,
    dietary_tags             = CASE WHEN p_data ? 'dietary_tags' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'dietary_tags'))::text[] ELSE dietary_tags END,
    health_tags              = CASE WHEN p_data ? 'health_tags' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'health_tags'))::text[] ELSE health_tags END,
    occasion_tags            = CASE WHEN p_data ? 'occasion_tags' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'occasion_tags'))::text[] ELSE occasion_tags END,
    style_tags               = CASE WHEN p_data ? 'style_tags' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'style_tags'))::text[] ELSE style_tags END,
    meal_type_tags           = CASE WHEN p_data ? 'meal_type_tags' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'meal_type_tags'))::text[] ELSE meal_type_tags END,
    flavor_profile_tags      = CASE WHEN p_data ? 'flavor_profile_tags' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'flavor_profile_tags'))::text[] ELSE flavor_profile_tags END,
    unknown_ingredients      = CASE WHEN p_data ? 'unknown_ingredients' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'unknown_ingredients'))::text[] ELSE unknown_ingredients END,
    unknown_utensils         = CASE WHEN p_data ? 'unknown_utensils' THEN ARRAY(SELECT jsonb_array_elements_text(p_data->'unknown_utensils'))::text[] ELSE unknown_utensils END,
    taxonomy_suggestions     = CASE WHEN p_data ? 'taxonomy_suggestions' THEN p_data->'taxonomy_suggestions' ELSE taxonomy_suggestions END
  WHERE id = p_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'recipe_not_found'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_save_recipe_review(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_save_recipe_review(uuid, jsonb) TO authenticated;

SELECT 'admin_save_recipe_review ready — run fix-admin-recipe-full-edit.sql once' AS status;

NOTIFY pgrst, 'reload schema';
