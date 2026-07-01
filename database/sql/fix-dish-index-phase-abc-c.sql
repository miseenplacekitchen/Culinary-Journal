-- fix-dish-index-phase-abc-c.sql — Part 3/3: list RPC (replaces list-filter.sql). Run last.

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
