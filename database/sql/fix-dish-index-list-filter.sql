-- fix-dish-index-list-filter.sql — Fix Archived queue (archived-only rows) + p_active_filter param.
-- Run once in Supabase SQL Editor after fix-dish-index-ops.sql. Safe to re-run.

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
    WHEN 'primary_ingredients' THEN 'primary_ingredients'
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

-- Accept "Hero Ingredient" CSV header (alias for primary_ingredients)
CREATE OR REPLACE FUNCTION public.rnl_csv_row_to_jsonb(r jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', COALESCE(r->>'id', r->>'ID'),
    'dish_code', COALESCE(r->>'dish_code', r->>'Dish Code', r->>'DI#'),
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
    'primary_ingredients', COALESCE(r->'primary_ingredients', to_jsonb(COALESCE(r->>'Hero Ingredient', r->>'Primary Ingredients', ''))),
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
