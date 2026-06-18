-- fix-admin-bulk-recipes-v2.sql — Bulk Editor expansion (run after fix-admin-bulk-recipes.sql).
-- Safe to re-run.

DROP FUNCTION IF EXISTS public.admin_get_recipes_bulk(int, int, text, text, text);
CREATE OR REPLACE FUNCTION public.admin_get_recipes_bulk(
  p_limit    int  DEFAULT 50,
  p_offset   int  DEFAULT 0,
  p_search   text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_status   text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total bigint;
  v_rows  json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT count(*) INTO v_total
    FROM public.submitted_recipes sr
   WHERE (p_search IS NULL OR btrim(p_search) = ''
          OR sr.recipe_name ILIKE '%' || p_search || '%'
          OR COALESCE(sr.recipe_code, '') ILIKE '%' || p_search || '%')
     AND (p_category IS NULL OR btrim(p_category) = '' OR sr.category = p_category)
     AND (p_status IS NULL OR btrim(p_status) = '' OR sr.status = p_status);

  SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) INTO v_rows
    FROM (
      SELECT
        sr.id,
        sr.recipe_code,
        sr.recipe_name,
        sr.category,
        sr.sub_category,
        sr.division,
        sr.cooking_style,
        sr.spice_level,
        sr.sweet_level,
        sr.difficulty,
        sr.visibility,
        sr.status,
        sr.dietary_tags,
        sr.style_tags,
        sr.health_tags,
        sr.occasion_tags,
        sr.meal_type_tags,
        sr.flavor_profile_tags,
        sr.submitted_at
      FROM public.submitted_recipes sr
     WHERE (p_search IS NULL OR btrim(p_search) = ''
            OR sr.recipe_name ILIKE '%' || p_search || '%'
            OR COALESCE(sr.recipe_code, '') ILIKE '%' || p_search || '%')
       AND (p_category IS NULL OR btrim(p_category) = '' OR sr.category = p_category)
       AND (p_status IS NULL OR btrim(p_status) = '' OR sr.status = p_status)
     ORDER BY sr.recipe_name ASC
     LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
     OFFSET greatest(0, coalesce(p_offset, 0))
    ) t;

  RETURN json_build_object('rows', v_rows, 'total', v_total);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_get_recipes_bulk(int, int, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_recipes_bulk(int, int, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_update_recipe_field(uuid, text, text);
CREATE OR REPLACE FUNCTION public.admin_update_recipe_field(
  p_id    uuid,
  p_field text,
  p_value text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tags text[];
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  IF p_field IN ('dietary_tags', 'style_tags', 'health_tags', 'occasion_tags', 'meal_type_tags', 'flavor_profile_tags') THEN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
      v_tags := '{}';
    ELSE
      SELECT coalesce(array_agg(btrim(x)), '{}') INTO v_tags
        FROM unnest(string_to_array(p_value, ',')) AS x
       WHERE btrim(x) <> '';
    END IF;
    EXECUTE format(
      'UPDATE public.submitted_recipes SET %I = $1 WHERE id = $2',
      p_field
    ) USING v_tags, p_id;
  ELSIF p_field = 'recipe_name' THEN
    UPDATE public.submitted_recipes SET recipe_name = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'recipe_code' THEN
    UPDATE public.submitted_recipes SET recipe_code = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'category' THEN
    UPDATE public.submitted_recipes SET category = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'sub_category' THEN
    UPDATE public.submitted_recipes SET sub_category = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'division' THEN
    UPDATE public.submitted_recipes SET division = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'cooking_style' THEN
    UPDATE public.submitted_recipes SET cooking_style = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'spice_level' THEN
    UPDATE public.submitted_recipes SET spice_level = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'sweet_level' THEN
    UPDATE public.submitted_recipes SET sweet_level = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'difficulty' THEN
    UPDATE public.submitted_recipes SET difficulty = nullif(btrim(p_value), '') WHERE id = p_id;
  ELSIF p_field = 'visibility' THEN
    IF p_value NOT IN ('Public', 'Private', 'Friends', 'Archived') THEN
      RAISE EXCEPTION 'Invalid visibility: %', p_value;
    END IF;
    UPDATE public.submitted_recipes SET visibility = p_value WHERE id = p_id;
  ELSIF p_field = 'status' THEN
    IF p_value NOT IN ('pending', 'approved', 'rejected') THEN
      RAISE EXCEPTION 'Invalid status: %', p_value;
    END IF;
    UPDATE public.submitted_recipes SET status = p_value WHERE id = p_id;
  ELSE
    RAISE EXCEPTION 'Unknown field: %', p_field;
  END IF;

  IF NOT FOUND THEN RAISE EXCEPTION 'recipe_not_found'; END IF;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_update_recipe_field(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_recipe_field(uuid, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_bulk_assign_recipe_taxonomy(uuid[], text, text, text);
CREATE OR REPLACE FUNCTION public.admin_bulk_assign_recipe_taxonomy(
  p_recipe_ids   uuid[],
  p_category     text DEFAULT NULL,
  p_sub_category text DEFAULT NULL,
  p_division     text DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_recipe_ids IS NULL OR array_length(p_recipe_ids, 1) IS NULL THEN RETURN 0; END IF;

  UPDATE public.submitted_recipes sr SET
    category = CASE WHEN p_category IS NOT NULL AND btrim(p_category) <> '' THEN btrim(p_category) ELSE sr.category END,
    sub_category = CASE WHEN p_sub_category IS NOT NULL AND btrim(p_sub_category) <> '' THEN btrim(p_sub_category) ELSE sr.sub_category END,
    division = CASE WHEN p_division IS NOT NULL AND btrim(p_division) <> '' THEN btrim(p_division) ELSE sr.division END
  WHERE sr.id = ANY(p_recipe_ids);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_bulk_assign_recipe_taxonomy(uuid[], text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_assign_recipe_taxonomy(uuid[], text, text, text) TO authenticated;

SELECT routine_name FROM information_schema.routines
 WHERE routine_schema = 'public'
   AND routine_name IN ('admin_get_recipes_bulk', 'admin_update_recipe_field', 'admin_bulk_assign_recipe_taxonomy')
 ORDER BY routine_name;
