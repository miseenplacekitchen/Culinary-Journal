-- fix-dish-index-columns.sql — Dish Index: extend recipe_name_library to mirror Submit a Recipe
-- metadata (everything except ingredients + method). Run once in Supabase SQL Editor. Safe to re-run.
-- Requires fix-recipe-name-library.sql to have been run first.

ALTER TABLE public.recipe_name_library
  ADD COLUMN IF NOT EXISTS introduction text DEFAULT '',
  ADD COLUMN IF NOT EXISTS description text DEFAULT '',
  ADD COLUMN IF NOT EXISTS image_url text DEFAULT '',
  ADD COLUMN IF NOT EXISTS image_source_url text DEFAULT '',
  ADD COLUMN IF NOT EXISTS prep_time_minutes integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cook_time_minutes integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS additional_time_minutes integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS servings integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS servings_unit text DEFAULT 'people',
  ADD COLUMN IF NOT EXISTS difficulty text DEFAULT '',
  ADD COLUMN IF NOT EXISTS spice_level text DEFAULT 'Not Applicable',
  ADD COLUMN IF NOT EXISTS sweet_level text DEFAULT 'Not Applicable',
  ADD COLUMN IF NOT EXISTS cooking_style text DEFAULT '',
  ADD COLUMN IF NOT EXISTS health_tags text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS flavor_profile_tags text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS equipment text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS cooking_notes text DEFAULT '',
  ADD COLUMN IF NOT EXISTS shelf_life_value text DEFAULT '',
  ADD COLUMN IF NOT EXISTS shelf_life_unit text DEFAULT 'months',
  ADD COLUMN IF NOT EXISTS shelf_life_storage text DEFAULT '',
  ADD COLUMN IF NOT EXISTS after_open_value text DEFAULT '',
  ADD COLUMN IF NOT EXISTS after_open_unit text DEFAULT 'weeks',
  ADD COLUMN IF NOT EXISTS source_type text DEFAULT 'Original',
  ADD COLUMN IF NOT EXISTS credit_name text DEFAULT '',
  ADD COLUMN IF NOT EXISTS credit_handle text DEFAULT '',
  ADD COLUMN IF NOT EXISTS credit_url text DEFAULT '',
  ADD COLUMN IF NOT EXISTS source_url text DEFAULT '';

CREATE OR REPLACE FUNCTION public.rnl_coalesce_int(p_row jsonb, p_key text, p_default int DEFAULT 0)
RETURNS int
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT COALESCE(NULLIF(regexp_replace(COALESCE(p_row->>p_key, ''), '\D', '', 'g'), '')::int, p_default);
$$;

CREATE OR REPLACE FUNCTION public.rnl_apply_row_fields(p_row jsonb)
RETURNS TABLE (
  recipe_name text,
  native_name text,
  alternate_names text[],
  category text,
  sub_category text,
  division text,
  origin_continent text,
  origin_country text,
  origin_state text,
  origin_locality text,
  primary_ingredients text[],
  dietary_tags text[],
  meal_type_tags text[],
  occasion_tags text[],
  style_tags text[],
  health_tags text[],
  flavor_profile_tags text[],
  equipment text[],
  introduction text,
  description text,
  image_url text,
  image_source_url text,
  prep_time_minutes integer,
  cook_time_minutes integer,
  additional_time_minutes integer,
  servings integer,
  servings_unit text,
  difficulty text,
  spice_level text,
  sweet_level text,
  cooking_style text,
  cooking_notes text,
  shelf_life_value text,
  shelf_life_unit text,
  shelf_life_storage text,
  after_open_value text,
  after_open_unit text,
  source_type text,
  credit_name text,
  credit_handle text,
  credit_url text,
  source_url text,
  source_notes text,
  research_status text,
  content_status text,
  notes text
)
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT
    btrim(p_row->>'recipe_name') AS recipe_name,
    COALESCE(NULLIF(btrim(p_row->>'native_name'), ''), '') AS native_name,
    public.rnl_text_array(p_row->'alternate_names') AS alternate_names,
    COALESCE(NULLIF(btrim(p_row->>'category'), ''), '') AS category,
    COALESCE(NULLIF(btrim(p_row->>'sub_category'), ''), '') AS sub_category,
    COALESCE(NULLIF(btrim(p_row->>'division'), ''), '') AS division,
    COALESCE(NULLIF(btrim(p_row->>'origin_continent'), ''), '') AS origin_continent,
    COALESCE(NULLIF(btrim(p_row->>'origin_country'), ''), '') AS origin_country,
    COALESCE(NULLIF(btrim(p_row->>'origin_state'), ''), '') AS origin_state,
    COALESCE(NULLIF(btrim(p_row->>'origin_locality'), ''), '') AS origin_locality,
    public.rnl_text_array(p_row->'primary_ingredients') AS primary_ingredients,
    public.rnl_text_array(p_row->'dietary_tags') AS dietary_tags,
    public.rnl_text_array(p_row->'meal_type_tags') AS meal_type_tags,
    public.rnl_text_array(p_row->'occasion_tags') AS occasion_tags,
    public.rnl_text_array(p_row->'style_tags') AS style_tags,
    public.rnl_text_array(p_row->'health_tags') AS health_tags,
    public.rnl_text_array(p_row->'flavor_profile_tags') AS flavor_profile_tags,
    public.rnl_text_array(p_row->'equipment') AS equipment,
    COALESCE(NULLIF(btrim(p_row->>'introduction'), ''), '') AS introduction,
    COALESCE(NULLIF(btrim(p_row->>'description'), ''), '') AS description,
    COALESCE(NULLIF(btrim(p_row->>'image_url'), ''), '') AS image_url,
    COALESCE(NULLIF(btrim(p_row->>'image_source_url'), ''), '') AS image_source_url,
    public.rnl_coalesce_int(p_row, 'prep_time_minutes', 0) AS prep_time_minutes,
    public.rnl_coalesce_int(p_row, 'cook_time_minutes', 0) AS cook_time_minutes,
    public.rnl_coalesce_int(p_row, 'additional_time_minutes', 0) AS additional_time_minutes,
    public.rnl_coalesce_int(p_row, 'servings', 0) AS servings,
    COALESCE(NULLIF(btrim(p_row->>'servings_unit'), ''), 'people') AS servings_unit,
    COALESCE(NULLIF(btrim(p_row->>'difficulty'), ''), '') AS difficulty,
    COALESCE(NULLIF(btrim(p_row->>'spice_level'), ''), 'Not Applicable') AS spice_level,
    COALESCE(NULLIF(btrim(p_row->>'sweet_level'), ''), 'Not Applicable') AS sweet_level,
    COALESCE(NULLIF(btrim(p_row->>'cooking_style'), ''), '') AS cooking_style,
    COALESCE(NULLIF(btrim(p_row->>'cooking_notes'), ''), '') AS cooking_notes,
    COALESCE(NULLIF(btrim(p_row->>'shelf_life_value'), ''), '') AS shelf_life_value,
    COALESCE(NULLIF(btrim(p_row->>'shelf_life_unit'), ''), 'months') AS shelf_life_unit,
    COALESCE(NULLIF(btrim(p_row->>'shelf_life_storage'), ''), '') AS shelf_life_storage,
    COALESCE(NULLIF(btrim(p_row->>'after_open_value'), ''), '') AS after_open_value,
    COALESCE(NULLIF(btrim(p_row->>'after_open_unit'), ''), 'weeks') AS after_open_unit,
    COALESCE(NULLIF(btrim(p_row->>'source_type'), ''), 'Original') AS source_type,
    COALESCE(NULLIF(btrim(p_row->>'credit_name'), ''), '') AS credit_name,
    COALESCE(NULLIF(btrim(p_row->>'credit_handle'), ''), '') AS credit_handle,
    COALESCE(NULLIF(btrim(p_row->>'credit_url'), ''), '') AS credit_url,
    COALESCE(NULLIF(btrim(p_row->>'source_url'), ''), '') AS source_url,
    COALESCE(NULLIF(btrim(p_row->>'source_notes'), ''), '') AS source_notes,
    COALESCE(NULLIF(btrim(p_row->>'research_status'), ''), 'idea_only') AS research_status,
    COALESCE(NULLIF(btrim(p_row->>'content_status'), ''), 'not_started') AS content_status,
    COALESCE(NULLIF(btrim(p_row->>'notes'), ''), '') AS notes;
$$;

DROP FUNCTION IF EXISTS public.admin_upsert_recipe_name_library(jsonb);
CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_name_library(p_row jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_recipe_id uuid;
  v record;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NULLIF(btrim(p_row->>'recipe_name'), '') IS NULL THEN
    RAISE EXCEPTION 'Recipe name is required';
  END IF;

  SELECT * INTO v FROM public.rnl_apply_row_fields(p_row);

  IF NULLIF(p_row->>'id', '') IS NOT NULL THEN
    v_id := (p_row->>'id')::uuid;
  END IF;
  IF NULLIF(p_row->>'linked_recipe_id', '') IS NOT NULL THEN
    v_recipe_id := (p_row->>'linked_recipe_id')::uuid;
  END IF;

  IF v_id IS NULL THEN
    SELECT id INTO v_id
      FROM public.recipe_name_library
     WHERE lower(btrim(recipe_name)) = lower(btrim(v.recipe_name))
       AND COALESCE(NULLIF(btrim(origin_country), ''), '') = COALESCE(NULLIF(btrim(v.origin_country), ''), '')
     LIMIT 1;
  END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.recipe_name_library (
      recipe_name, native_name, alternate_names,
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
      research_status, content_status, linked_recipe_id, notes
    ) VALUES (
      v.recipe_name, v.native_name, v.alternate_names,
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
      v.research_status, v.content_status, v_recipe_id, v.notes
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_name_library SET
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
      notes = v.notes
    WHERE id = v_id
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_import_recipe_name_library(jsonb);
CREATE OR REPLACE FUNCTION public.admin_import_recipe_name_library(p_rows jsonb)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r jsonb;
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
    IF NULLIF(btrim(COALESCE(r->>'recipe_name', r->>'Recipe Name', r->>'Name')), '') IS NULL THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;
    r := jsonb_build_object(
      'id', COALESCE(r->>'id', r->>'ID'),
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
      'notes', COALESCE(r->>'notes', r->>'Notes')
    );

    SELECT EXISTS (
      SELECT 1 FROM public.recipe_name_library
      WHERE lower(btrim(recipe_name)) = lower(btrim(r->>'recipe_name'))
        AND COALESCE(NULLIF(btrim(origin_country), ''), '') = COALESCE(NULLIF(btrim(r->>'origin_country'), ''), '')
    ) INTO v_exists;
    v_id := public.admin_upsert_recipe_name_library(r);
    IF v_exists THEN v_updated := v_updated + 1; ELSE v_inserted := v_inserted + 1; END IF;
  END LOOP;

  RETURN json_build_object('inserted', v_inserted, 'updated', v_updated, 'skipped', v_skipped);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_import_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_import_recipe_name_library(jsonb) TO authenticated;

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
    introduction, description, image_url,
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
    COALESCE(r.introduction, ''), COALESCE(r.description, ''), COALESCE(r.image_url, ''),
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
