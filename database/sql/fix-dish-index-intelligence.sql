-- fix-dish-index-intelligence.sql — Phase 4 intelligence RPCs for Dish Index
-- Duplicate name clusters + coverage gap reports.
-- Safe to re-run. Run after fix-dish-index-phase-abc.sql (step 6).

-- ── Normalize helper (immutable) ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rnl_normalize_name(p text)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT lower(regexp_replace(btrim(COALESCE(p, '')), '[^a-z0-9]+', '', 'g'));
$$;

-- ── 1. Duplicate clusters (normalized recipe_name groups with 2+ active rows) ─
DROP FUNCTION IF EXISTS public.admin_dish_index_duplicate_clusters(int);
CREATE OR REPLACE FUNCTION public.admin_dish_index_duplicate_clusters(p_limit int DEFAULT 50)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_limit int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  RETURN COALESCE((
    WITH norm AS (
      SELECT
        r.id,
        r.dish_code,
        r.recipe_name,
        r.native_name,
        r.origin_country,
        r.category,
        r.linked_recipe_id,
        r.created_at,
        public.rnl_normalize_name(r.recipe_name) AS norm_name
      FROM public.recipe_name_library r
      WHERE COALESCE(r.is_active, true) = true
        AND btrim(COALESCE(r.recipe_name, '')) <> ''
    ),
    groups AS (
      SELECT
        norm_name AS group_key,
        count(*)::int AS cnt,
        json_agg(
          json_build_object(
            'id', id,
            'dish_code', dish_code,
            'recipe_name', recipe_name,
            'native_name', native_name,
            'origin_country', origin_country,
            'category', category,
            'linked_recipe_id', linked_recipe_id
          )
          ORDER BY created_at NULLS LAST, dish_code NULLS LAST
        ) AS rows
      FROM norm
      WHERE norm_name <> ''
      GROUP BY norm_name
      HAVING count(*) > 1
    )
    SELECT json_build_object(
      'clusters',
      COALESCE((
        SELECT json_agg(
          json_build_object(
            'group_key', g.group_key,
            'match_on', 'recipe_name',
            'count', g.cnt,
            'rows', g.rows
          )
          ORDER BY g.cnt DESC, g.group_key
        )
        FROM (
          SELECT * FROM groups
          ORDER BY cnt DESC, group_key
          LIMIT v_limit
        ) g
      ), '[]'::json),
      'total_clusters', (SELECT count(*)::int FROM groups)
    )
  ), json_build_object('clusters', '[]'::json, 'total_clusters', 0));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_dish_index_duplicate_clusters(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dish_index_duplicate_clusters(int) TO authenticated;

-- ── 2. Coverage gaps (missing taxonomy/geo + empty categories) ───────────────
DROP FUNCTION IF EXISTS public.admin_dish_index_coverage_gaps(int);
CREATE OR REPLACE FUNCTION public.admin_dish_index_coverage_gaps(p_row_limit int DEFAULT 100)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row_limit int := LEAST(GREATEST(COALESCE(p_row_limit, 100), 1), 500);
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  RETURN json_build_object(
    'missing_category', COALESCE((
      SELECT json_agg(row_to_json(t))
        FROM (
          SELECT id, dish_code, recipe_name, origin_country, category, sub_category
            FROM public.recipe_name_library
           WHERE COALESCE(is_active, true) = true
             AND btrim(COALESCE(category, '')) = ''
           ORDER BY recipe_name ASC
           LIMIT v_row_limit
        ) t
    ), '[]'::json),
    'missing_country', COALESCE((
      SELECT json_agg(row_to_json(t))
        FROM (
          SELECT id, dish_code, recipe_name, origin_country, category, sub_category
            FROM public.recipe_name_library
           WHERE COALESCE(is_active, true) = true
             AND btrim(COALESCE(origin_country, '')) = ''
           ORDER BY recipe_name ASC
           LIMIT v_row_limit
        ) t
    ), '[]'::json),
    'missing_sub_category', COALESCE((
      SELECT json_agg(row_to_json(t))
        FROM (
          SELECT id, dish_code, recipe_name, origin_country, category, sub_category
            FROM public.recipe_name_library
           WHERE COALESCE(is_active, true) = true
             AND btrim(COALESCE(category, '')) <> ''
             AND btrim(COALESCE(sub_category, '')) = ''
           ORDER BY category, recipe_name ASC
           LIMIT v_row_limit
        ) t
    ), '[]'::json),
    'empty_categories', COALESCE((
      SELECT json_agg(row_to_json(t) ORDER BY t.category)
        FROM (
          SELECT DISTINCT sc.category AS category, 0::int AS index_count
            FROM public.recipe_subcategories sc
           WHERE COALESCE(sc.is_active, false) = true
             AND btrim(COALESCE(sc.category, '')) <> ''
             AND NOT EXISTS (
               SELECT 1
                 FROM public.recipe_name_library r
                WHERE COALESCE(r.is_active, true) = true
                  AND btrim(COALESCE(r.category, '')) = sc.category
             )
        ) t
    ), '[]'::json),
    'category_counts', COALESCE((
      SELECT json_agg(row_to_json(t) ORDER BY t.count DESC, t.category)
        FROM (
          SELECT btrim(category) AS category, count(*)::int AS count
            FROM public.recipe_name_library
           WHERE COALESCE(is_active, true) = true
             AND btrim(COALESCE(category, '')) <> ''
           GROUP BY btrim(category)
        ) t
    ), '[]'::json),
    'country_counts', COALESCE((
      SELECT json_agg(row_to_json(t) ORDER BY t.count DESC, t.country)
        FROM (
          SELECT btrim(origin_country) AS country, count(*)::int AS count
            FROM public.recipe_name_library
           WHERE COALESCE(is_active, true) = true
             AND btrim(COALESCE(origin_country, '')) <> ''
           GROUP BY btrim(origin_country)
        ) t
    ), '[]'::json),
    'summary', json_build_object(
      'missing_category_count', (
        SELECT count(*)::int FROM public.recipe_name_library
         WHERE COALESCE(is_active, true) = true AND btrim(COALESCE(category, '')) = ''
      ),
      'missing_country_count', (
        SELECT count(*)::int FROM public.recipe_name_library
         WHERE COALESCE(is_active, true) = true AND btrim(COALESCE(origin_country, '')) = ''
      ),
      'missing_sub_category_count', (
        SELECT count(*)::int FROM public.recipe_name_library
         WHERE COALESCE(is_active, true) = true
           AND btrim(COALESCE(category, '')) <> ''
           AND btrim(COALESCE(sub_category, '')) = ''
      ),
      'empty_category_count', (
        SELECT count(DISTINCT sc.category)::int
          FROM public.recipe_subcategories sc
         WHERE COALESCE(sc.is_active, false) = true
           AND btrim(COALESCE(sc.category, '')) <> ''
           AND NOT EXISTS (
             SELECT 1 FROM public.recipe_name_library r
              WHERE COALESCE(r.is_active, true) = true
                AND btrim(COALESCE(r.category, '')) = sc.category
           )
      ),
      'active_dish_count', (
        SELECT count(*)::int FROM public.recipe_name_library
         WHERE COALESCE(is_active, true) = true
      )
    )
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_dish_index_coverage_gaps(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dish_index_coverage_gaps(int) TO authenticated;

SELECT 'fix-dish-index-intelligence complete' AS status;
