-- fix-dish-index-ops.sql — Dish Index long-term ops: identity, validation, bulk, sync, import preview.
-- Run after fix-recipe-name-library.sql and fix-dish-index-columns.sql. Safe to re-run.

ALTER TABLE public.recipe_name_library
  ADD COLUMN IF NOT EXISTS dish_code text DEFAULT '',
  ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS schema_version text DEFAULT '20260702';

CREATE UNIQUE INDEX IF NOT EXISTS idx_recipe_name_library_dish_code
  ON public.recipe_name_library (dish_code)
  WHERE dish_code IS NOT NULL AND btrim(dish_code) <> '';

CREATE INDEX IF NOT EXISTS idx_recipe_name_library_active
  ON public.recipe_name_library (is_active)
  WHERE is_active = true;

CREATE SEQUENCE IF NOT EXISTS public.dish_index_code_seq START 1;

CREATE OR REPLACE FUNCTION public.rnl_next_dish_code()
RETURNS text
LANGUAGE plpgsql SET search_path = public
AS $$
DECLARE
  v_seq bigint;
BEGIN
  v_seq := nextval('public.dish_index_code_seq');
  RETURN 'DI' || lpad(v_seq::text, 6, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public.rnl_validate_taxonomy(
  p_category text,
  p_sub_category text,
  p_division text
)
RETURNS text[]
LANGUAGE plpgsql STABLE SET search_path = public
AS $$
DECLARE
  v_warnings text[] := '{}';
  v_cat text := NULLIF(btrim(p_category), '');
  v_sub text := NULLIF(btrim(p_sub_category), '');
  v_div text := NULLIF(btrim(p_division), '');
BEGIN
  IF v_cat IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.categories c
     WHERE c.name = v_cat AND COALESCE(c.is_active, true) = true
  ) THEN
    v_warnings := array_append(v_warnings, 'Unknown or inactive category: ' || v_cat);
  END IF;

  IF v_sub IS NOT NULL AND v_cat IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.recipe_subcategories sc
     WHERE sc.category = v_cat AND sc.name = v_sub AND COALESCE(sc.is_active, false) = true
  ) THEN
    v_warnings := array_append(v_warnings, 'Unknown or inactive sub-category: ' || v_sub);
  END IF;

  IF v_div IS NOT NULL AND v_cat IS NOT NULL AND v_sub IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.recipe_divisions d
     WHERE d.category = v_cat AND d.subcategory = v_sub AND d.name = v_div
       AND COALESCE(d.is_active, false) = true
  ) THEN
    v_warnings := array_append(v_warnings, 'Unknown or inactive division: ' || v_div);
  END IF;

  RETURN v_warnings;
END;
$$;

CREATE OR REPLACE FUNCTION public.rnl_has_drift(p_rnl public.recipe_name_library, p_sr public.submitted_recipes)
RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT
    lower(btrim(COALESCE(p_rnl.recipe_name, ''))) IS DISTINCT FROM lower(btrim(COALESCE(p_sr.recipe_name, '')))
    OR lower(btrim(COALESCE(p_rnl.native_name, ''))) IS DISTINCT FROM lower(btrim(COALESCE(p_sr.native_title, '')))
    OR COALESCE(NULLIF(btrim(p_rnl.category), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.category), ''), '')
    OR COALESCE(NULLIF(btrim(p_rnl.sub_category), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.sub_category), ''), '')
    OR COALESCE(NULLIF(btrim(p_rnl.division), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.division), ''), '')
    OR COALESCE(NULLIF(btrim(p_rnl.origin_country), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.origin_country), ''), '')
    OR COALESCE(p_rnl.spice_level, '') IS DISTINCT FROM COALESCE(p_sr.spice_level, '')
    OR COALESCE(p_rnl.difficulty, '') IS DISTINCT FROM COALESCE(p_sr.difficulty, '')
    OR COALESCE(NULLIF(btrim(p_rnl.introduction), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(p_sr.introduction), ''), '');
$$;

CREATE OR REPLACE FUNCTION public.rnl_csv_row_to_jsonb(r jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', COALESCE(r->>'id', r->>'ID'),
    'dish_code', COALESCE(r->>'dish_code', r->>'Dish Code'),
    'recipe_name', COALESCE(r->>'recipe_name', r->>'Recipe Name', r->>'Name'),
    'native_name', COALESCE(r->>'native_name', r->>'Native Name'),
    'alternate_names', COALESCE(r->'alternate_names', to_jsonb(COALESCE(r->>'Alternate Names', ''))),
    'category', COALESCE(r->>'category', r->>'Category'),
    'sub_category', COALESCE(r->>'sub_category', r->>'Sub-category', r->>'Sub Category'),
    'division', COALESCE(r->>'division', r->>'Division'),
    'origin_continent', COALESCE(r->>'origin_continent', r->>'Continent'),
    'origin_country', COALESCE(r->>'origin_country', r->>'Country'),
    'origin_state', COALESCE(r->>'origin_state', r->>'State'),
    'origin_locality', COALESCE(r->>'origin_locality', r->>'Locality'),
    'primary_ingredients', COALESCE(r->'primary_ingredients', to_jsonb(COALESCE(r->>'Primary Ingredients', ''))),
    'dietary_tags', COALESCE(r->'dietary_tags', to_jsonb(COALESCE(r->>'Dietary Tags', ''))),
    'meal_type_tags', COALESCE(r->'meal_type_tags', to_jsonb(COALESCE(r->>'Meal Type Tags', ''))),
    'occasion_tags', COALESCE(r->'occasion_tags', to_jsonb(COALESCE(r->>'Occasion Tags', ''))),
    'style_tags', COALESCE(r->'style_tags', to_jsonb(COALESCE(r->>'Style Tags', ''))),
    'health_tags', COALESCE(r->'health_tags', to_jsonb(COALESCE(r->>'Health Tags', ''))),
    'flavor_profile_tags', COALESCE(r->'flavor_profile_tags', to_jsonb(COALESCE(r->>'Flavor Profile Tags', r->>'Flavor Tags', ''))),
    'equipment', COALESCE(r->'equipment', to_jsonb(COALESCE(r->>'Equipment', ''))),
    'introduction', COALESCE(r->>'introduction', r->>'Introduction'),
    'description', COALESCE(r->>'description', r->>'Description'),
    'image_url', COALESCE(r->>'image_url', r->>'Image URL'),
    'image_source_url', COALESCE(r->>'image_source_url', r->>'Image Source URL'),
    'prep_time_minutes', COALESCE(r->>'prep_time_minutes', r->>'Prep Time Minutes', r->>'Prep Time'),
    'cook_time_minutes', COALESCE(r->>'cook_time_minutes', r->>'Cook Time Minutes', r->>'Cook Time'),
    'additional_time_minutes', COALESCE(r->>'additional_time_minutes', r->>'Additional Time Minutes', r->>'Additional Time'),
    'servings', COALESCE(r->>'servings', r->>'Servings'),
    'servings_unit', COALESCE(r->>'servings_unit', r->>'Servings Unit'),
    'difficulty', COALESCE(r->>'difficulty', r->>'Difficulty'),
    'spice_level', COALESCE(r->>'spice_level', r->>'Spice Level'),
    'sweet_level', COALESCE(r->>'sweet_level', r->>'Sweet Level'),
    'cooking_style', COALESCE(r->>'cooking_style', r->>'Cooking Style'),
    'cooking_notes', COALESCE(r->>'cooking_notes', r->>'Cooking Notes'),
    'shelf_life_value', COALESCE(r->>'shelf_life_value', r->>'Shelf Life Value'),
    'shelf_life_unit', COALESCE(r->>'shelf_life_unit', r->>'Shelf Life Unit'),
    'shelf_life_storage', COALESCE(r->>'shelf_life_storage', r->>'Shelf Life Storage'),
    'after_open_value', COALESCE(r->>'after_open_value', r->>'After Open Value'),
    'after_open_unit', COALESCE(r->>'after_open_unit', r->>'After Open Unit'),
    'source_type', COALESCE(r->>'source_type', r->>'Source Type'),
    'credit_name', COALESCE(r->>'credit_name', r->>'Credit Name'),
    'credit_handle', COALESCE(r->>'credit_handle', r->>'Credit Handle'),
    'credit_url', COALESCE(r->>'credit_url', r->>'Credit URL'),
    'source_url', COALESCE(r->>'source_url', r->>'Source URL'),
    'source_notes', COALESCE(r->>'source_notes', r->>'Source Notes'),
    'research_status', COALESCE(r->>'research_status', r->>'Research Status'),
    'content_status', COALESCE(r->>'content_status', r->>'Content Status'),
    'linked_recipe_id', COALESCE(r->>'linked_recipe_id', r->>'Linked Recipe ID'),
    'notes', COALESCE(r->>'notes', r->>'Notes'),
    'is_active', COALESCE(r->>'is_active', r->>'Active', 'true')
  );
$$;

-- Replace list RPC with extended filters + dish_code + drift flag
DROP FUNCTION IF EXISTS public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text, text, text, boolean, text);

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
  p_include_archived boolean DEFAULT false,
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
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_order_col := CASE p_sort_col
    WHEN 'dish_code' THEN 'dish_code'
    WHEN 'native_name' THEN 'native_name'
    WHEN 'category' THEN 'category'
    WHEN 'sub_category' THEN 'sub_category'
    WHEN 'division' THEN 'division'
    WHEN 'origin_country' THEN 'origin_country'
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
   WHERE (p_include_archived OR COALESCE(rnl.is_active, true) = true)
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
         WHERE ($8 OR COALESCE(rnl.is_active, true) = true)
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
        p_limit, p_offset, p_include_archived, p_sub_category, p_division, p_drift;

  RETURN json_build_object('total', v_total, 'rows', COALESCE(v_rows, '[]'::json));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text, text, text, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text, text, text, boolean, text) TO authenticated;

-- Assign dish_code on insert in upsert (patch via wrapper logic in new upsert isn't needed if we patch existing function)
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
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NULLIF(btrim(p_row->>'recipe_name'), '') IS NULL THEN
    RAISE EXCEPTION 'Recipe name is required';
  END IF;

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
      research_status, content_status, linked_recipe_id, notes, is_active, schema_version
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
      v.research_status, v.content_status, v_recipe_id, v.notes,
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

DROP FUNCTION IF EXISTS public.admin_preview_import_recipe_name_library(jsonb);
CREATE OR REPLACE FUNCTION public.admin_preview_import_recipe_name_library(p_rows jsonb)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r jsonb;
  v_row jsonb;
  v_idx int := 0;
  v_out jsonb := '[]'::jsonb;
  v_insert int := 0;
  v_update int := 0;
  v_skip int := 0;
  v_error int := 0;
  v_action text;
  v_id uuid;
  v_name text;
  v_country text;
  v_warnings text[];
  v_fields record;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'Rows must be a JSON array';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_idx := v_idx + 1;
    v_row := public.rnl_csv_row_to_jsonb(r);
    v_name := NULLIF(btrim(v_row->>'recipe_name'), '');
    v_country := COALESCE(NULLIF(btrim(v_row->>'origin_country'), ''), '');
    v_warnings := '{}';

    IF v_name IS NULL THEN
      v_action := 'skip';
      v_skip := v_skip + 1;
      v_warnings := array_append(v_warnings, 'Missing recipe name');
    ELSE
      SELECT * INTO v_fields FROM public.rnl_apply_row_fields(v_row);
      v_warnings := v_warnings || public.rnl_validate_taxonomy(v_fields.category, v_fields.sub_category, v_fields.division);

      v_id := NULL;
      IF NULLIF(v_row->>'id', '') IS NOT NULL THEN
        SELECT id INTO v_id FROM public.recipe_name_library WHERE id = (v_row->>'id')::uuid;
      END IF;
      IF v_id IS NULL AND NULLIF(btrim(COALESCE(v_row->>'dish_code', '')), '') IS NOT NULL THEN
        SELECT id INTO v_id FROM public.recipe_name_library WHERE dish_code = btrim(v_row->>'dish_code') LIMIT 1;
      END IF;
      IF v_id IS NULL THEN
        SELECT id INTO v_id FROM public.recipe_name_library
         WHERE lower(btrim(recipe_name)) = lower(v_name)
           AND COALESCE(NULLIF(btrim(origin_country), ''), '') = v_country
           AND COALESCE(is_active, true) = true
         LIMIT 1;
      END IF;

      IF v_id IS NULL THEN
        v_action := 'insert';
        v_insert := v_insert + 1;
      ELSE
        v_action := 'update';
        v_update := v_update + 1;
      END IF;

      IF EXISTS (
        SELECT 1 FROM public.recipe_name_library x
         WHERE x.id IS DISTINCT FROM v_id
           AND lower(btrim(x.recipe_name)) = lower(v_name)
           AND COALESCE(NULLIF(btrim(x.origin_country), ''), '') = v_country
           AND COALESCE(x.is_active, true) = true
      ) THEN
        v_warnings := array_append(v_warnings, 'Possible duplicate identity');
        v_error := v_error + 1;
      END IF;
    END IF;

    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'row_num', v_idx,
      'recipe_name', COALESCE(v_name, ''),
      'dish_code', COALESCE(v_row->>'dish_code', ''),
      'action', v_action,
      'existing_id', v_id,
      'warnings', to_jsonb(COALESCE(v_warnings, '{}'))
    ));
  END LOOP;

  RETURN json_build_object(
    'rows', v_out,
    'summary', json_build_object('insert', v_insert, 'update', v_update, 'skip', v_skip, 'error', v_error)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_preview_import_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_preview_import_recipe_name_library(jsonb) TO authenticated;

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
    is_active = CASE WHEN p_fields ? 'is_active' THEN COALESCE((p_fields->>'is_active')::boolean, r.is_active) ELSE r.is_active END
  WHERE r.id = ANY(p_ids);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('updated', v_count, 'warnings', COALESCE(v_warnings, '{}'));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_bulk_update_recipe_name_library(uuid[], jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_update_recipe_name_library(uuid[], jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_merge_recipe_name_library(uuid, uuid);
CREATE OR REPLACE FUNCTION public.admin_merge_recipe_name_library(p_keep_id uuid, p_merge_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_keep public.recipe_name_library%ROWTYPE;
  v_merge public.recipe_name_library%ROWTYPE;
  v_alts text[];
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_keep_id = p_merge_id THEN RAISE EXCEPTION 'Cannot merge a row into itself'; END IF;

  SELECT * INTO v_keep FROM public.recipe_name_library WHERE id = p_keep_id AND COALESCE(is_active, true);
  IF NOT FOUND THEN RAISE EXCEPTION 'Keep row not found or archived'; END IF;
  SELECT * INTO v_merge FROM public.recipe_name_library WHERE id = p_merge_id AND COALESCE(is_active, true);
  IF NOT FOUND THEN RAISE EXCEPTION 'Merge source not found or archived'; END IF;

  v_alts := COALESCE(v_keep.alternate_names, '{}');
  IF NULLIF(btrim(v_merge.recipe_name), '') IS NOT NULL THEN
    v_alts := v_alts || ARRAY[btrim(v_merge.recipe_name)];
  END IF;
  IF NULLIF(btrim(v_merge.native_name), '') IS NOT NULL THEN
    v_alts := v_alts || ARRAY[btrim(v_merge.native_name)];
  END IF;
  v_alts := v_alts || COALESCE(v_merge.alternate_names, '{}');

  UPDATE public.recipe_name_library SET
    alternate_names = (SELECT COALESCE(array_agg(DISTINCT x), '{}') FROM unnest(v_alts) x WHERE NULLIF(btrim(x), '') IS NOT NULL),
    linked_recipe_id = COALESCE(v_keep.linked_recipe_id, v_merge.linked_recipe_id),
    notes = COALESCE(v_keep.notes, '') || CASE WHEN NULLIF(v_merge.notes, '') IS NOT NULL THEN E'\nMerged from ' || v_merge.dish_code || ': ' || v_merge.notes ELSE '' END
  WHERE id = p_keep_id;

  UPDATE public.recipe_name_library SET
    is_active = false,
    content_status = 'duplicate',
    notes = COALESCE(notes, '') || E'\nMerged into ' || v_keep.dish_code
  WHERE id = p_merge_id;

  RETURN p_keep_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_merge_recipe_name_library(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_merge_recipe_name_library(uuid, uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_find_duplicate_name_library(text, int);
CREATE OR REPLACE FUNCTION public.admin_find_duplicate_name_library(p_search text, p_limit int DEFAULT 20)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN COALESCE((
    SELECT json_agg(row_to_json(t))
      FROM (
        SELECT id, dish_code, recipe_name, native_name, origin_country, category, linked_recipe_id
          FROM public.recipe_name_library
         WHERE COALESCE(is_active, true) = true
           AND (p_search IS NULL OR btrim(p_search) = ''
                OR recipe_name ILIKE '%' || p_search || '%'
                OR native_name ILIKE '%' || p_search || '%'
                OR EXISTS (SELECT 1 FROM unnest(COALESCE(alternate_names, '{}')) a WHERE a ILIKE '%' || p_search || '%'))
         ORDER BY recipe_name ASC
         LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100)
      ) t
  ), '[]'::json);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_find_duplicate_name_library(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_find_duplicate_name_library(text, int) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_search_recipes_for_link(text, int);
CREATE OR REPLACE FUNCTION public.admin_search_recipes_for_link(p_search text, p_limit int DEFAULT 15)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN COALESCE((
    SELECT json_agg(row_to_json(t))
      FROM (
        SELECT id, recipe_code, recipe_name, native_title, category, status
          FROM public.submitted_recipes sr
         WHERE p_search IS NOT NULL AND btrim(p_search) <> ''
           AND (sr.recipe_name ILIKE '%' || p_search || '%'
                OR sr.native_title ILIKE '%' || p_search || '%'
                OR COALESCE(sr.recipe_code, '') ILIKE '%' || p_search || '%')
         ORDER BY sr.submitted_at DESC NULLS LAST
         LIMIT LEAST(GREATEST(COALESCE(p_limit, 15), 1), 50)
      ) t
  ), '[]'::json);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_search_recipes_for_link(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_search_recipes_for_link(text, int) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_name_library_for_recipe(uuid);
CREATE OR REPLACE FUNCTION public.admin_get_name_library_for_recipe(p_recipe_id uuid)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT row_to_json(rnl) INTO v_row
    FROM public.recipe_name_library rnl
   WHERE rnl.linked_recipe_id = p_recipe_id AND COALESCE(rnl.is_active, true) = true
   LIMIT 1;
  RETURN COALESCE(v_row, '{}'::json);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_get_name_library_for_recipe(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_name_library_for_recipe(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_name_library_drift(uuid);
CREATE OR REPLACE FUNCTION public.admin_name_library_drift(p_id uuid)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_rnl public.recipe_name_library%ROWTYPE;
  v_sr public.submitted_recipes%ROWTYPE;
  v_fields jsonb := '[]'::jsonb;
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

  IF lower(btrim(COALESCE(v_rnl.recipe_name, ''))) IS DISTINCT FROM lower(btrim(COALESCE(v_sr.recipe_name, ''))) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'recipe_name', 'index', v_rnl.recipe_name, 'recipe', v_sr.recipe_name));
  END IF;
  IF lower(btrim(COALESCE(v_rnl.native_name, ''))) IS DISTINCT FROM lower(btrim(COALESCE(v_sr.native_title, ''))) THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'native_name', 'index', v_rnl.native_name, 'recipe', v_sr.native_title));
  END IF;
  IF COALESCE(NULLIF(btrim(v_rnl.category), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(v_sr.category), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'category', 'index', v_rnl.category, 'recipe', v_sr.category));
  END IF;
  IF COALESCE(NULLIF(btrim(v_rnl.sub_category), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(v_sr.sub_category), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'sub_category', 'index', v_rnl.sub_category, 'recipe', v_sr.sub_category));
  END IF;
  IF COALESCE(NULLIF(btrim(v_rnl.division), ''), '') IS DISTINCT FROM COALESCE(NULLIF(btrim(v_sr.division), ''), '') THEN
    v_fields := v_fields || jsonb_build_array(jsonb_build_object('field', 'division', 'index', v_rnl.division, 'recipe', v_sr.division));
  END IF;

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

  v_equipment := COALESCE((
    SELECT array_agg(x #>> '{}')
      FROM jsonb_array_elements(COALESCE(sr.equipment, '[]'::jsonb)) x
  ), '{}');

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

-- Backfill dish codes for existing rows
UPDATE public.recipe_name_library
   SET dish_code = public.rnl_next_dish_code()
 WHERE dish_code IS NULL OR btrim(dish_code) = '';

REVOKE ALL ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_import_recipe_name_library(jsonb);
CREATE OR REPLACE FUNCTION public.admin_import_recipe_name_library(p_rows jsonb)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r jsonb;
  v_row jsonb;
  v_id uuid;
  v_inserted int := 0;
  v_updated int := 0;
  v_skipped int := 0;
  v_exists boolean;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'Rows must be a JSON array';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_row := public.rnl_csv_row_to_jsonb(r);
    IF NULLIF(btrim(v_row->>'recipe_name'), '') IS NULL THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    SELECT EXISTS (
      SELECT 1 FROM public.recipe_name_library
      WHERE id IS NOT NULL
        AND (
          (NULLIF(v_row->>'id', '') IS NOT NULL AND id = (v_row->>'id')::uuid)
          OR (NULLIF(btrim(COALESCE(v_row->>'dish_code', '')), '') IS NOT NULL AND dish_code = btrim(v_row->>'dish_code'))
          OR (lower(btrim(recipe_name)) = lower(btrim(v_row->>'recipe_name'))
              AND COALESCE(NULLIF(btrim(origin_country), ''), '') = COALESCE(NULLIF(btrim(v_row->>'origin_country'), ''), ''))
        )
    ) INTO v_exists;

    v_id := public.admin_upsert_recipe_name_library(v_row);
    IF v_exists THEN v_updated := v_updated + 1; ELSE v_inserted := v_inserted + 1; END IF;
  END LOOP;

  RETURN json_build_object('inserted', v_inserted, 'updated', v_updated, 'skipped', v_skipped);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_import_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_import_recipe_name_library(jsonb) TO authenticated;
