-- fix-dish-index-phase-abc-b.sql — Part 2/3: sync, restore, queue counts. Run after -a.sql.

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

