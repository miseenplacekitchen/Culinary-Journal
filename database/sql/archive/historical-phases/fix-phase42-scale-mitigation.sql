-- fix-phase42-scale-mitigation.sql
-- Server-side stats, chef directory, baby browse, ingredient-linked recipes, admin search offset.
-- Safe to re-run.

-- ── 1. Homepage trust strip counts (no full-table REST fetch) ─────────
DROP FUNCTION IF EXISTS public.get_public_site_stats();
CREATE OR REPLACE FUNCTION public.get_public_site_stats()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'recipes', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
    'countries', (
      SELECT count(DISTINCT origin_country)::int FROM public.submitted_recipes
      WHERE status = 'approved' AND origin_country IS NOT NULL AND btrim(origin_country) <> ''
    ),
    'contributors', (
      SELECT count(DISTINCT user_id)::int FROM public.submitted_recipes
      WHERE status = 'approved' AND user_id IS NOT NULL
    ),
    'collections', (SELECT count(*)::int FROM public.collections WHERE is_public = true)
  );
$$;
GRANT EXECUTE ON FUNCTION public.get_public_site_stats() TO anon, authenticated;

-- ── 2. Chef directory (aggregated — no 100-recipe cap) ────────────────
DROP FUNCTION IF EXISTS public.get_chef_directory();
CREATE OR REPLACE FUNCTION public.get_chef_directory()
RETURNS TABLE (
  chef_name       text,
  credit_handle   text,
  username        text,
  recipe_count    bigint,
  countries       text[],
  categories      text[],
  is_cj_original  boolean
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    btrim(sr.credit_name) AS chef_name,
    max(sr.credit_handle) AS credit_handle,
    max(p.username)       AS username,
    count(*)::bigint      AS recipe_count,
    array_remove(array_agg(DISTINCT sr.origin_country), NULL) AS countries,
    array_remove(array_agg(DISTINCT sr.category), NULL)       AS categories,
    bool_or(sr.source_type = 'Original') AS is_cj_original
  FROM public.submitted_recipes sr
  LEFT JOIN public.profiles p ON p.id = sr.user_id
  WHERE sr.status = 'approved'
    AND sr.visibility = 'Public'
    AND btrim(coalesce(sr.credit_name, '')) <> ''
  GROUP BY btrim(sr.credit_name)
  ORDER BY count(*) DESC, btrim(sr.credit_name) ASC;
$$;
GRANT EXECUTE ON FUNCTION public.get_chef_directory() TO anon, authenticated;

-- ── 3. Baby food browse (ingredients + tags for safety filters) ─────
DROP FUNCTION IF EXISTS public.get_baby_browse_recipes(int, int);
CREATE OR REPLACE FUNCTION public.get_baby_browse_recipes(
  p_limit  int DEFAULT 48,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id              uuid,
  recipe_name     text,
  category        text,
  origin_country  text,
  image_url       text,
  dietary_tags    text[],
  occasion_tags   text[],
  health_tags     text[],
  ingredients     jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 48), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.category, sr.origin_country, sr.image_url,
         sr.dietary_tags, sr.occasion_tags, sr.health_tags, sr.ingredients
    FROM public.submitted_recipes sr
   WHERE sr.status = 'approved'
     AND sr.visibility = 'Public'
     AND sr.category = 'Little Ones'
   ORDER BY sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_baby_browse_recipes(int, int) TO anon, authenticated;

-- ── 4. Recipes using a governed ingredient (library profile links) ────
DROP FUNCTION IF EXISTS public.get_recipes_using_ingredient(int, int, int);
CREATE OR REPLACE FUNCTION public.get_recipes_using_ingredient(
  p_ingredient_id int,
  p_limit         int DEFAULT 12,
  p_offset        int DEFAULT 0
)
RETURNS TABLE (
  id          uuid,
  recipe_name text,
  image_url   text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_names text[] := ARRAY[]::text[];
  v_aka   text;
  v_part  text;
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 12), 48));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  IF p_ingredient_id IS NULL THEN RETURN; END IF;

  SELECT array_agg(DISTINCT lower(btrim(n)))
  INTO v_names
  FROM (
    SELECT i."Ingredient Name" AS n FROM ingredients i WHERE i."ID" = p_ingredient_id
    UNION ALL
    SELECT unnest(string_to_array(coalesce(i."Also Known As", ''), ',')) AS n
    FROM ingredients i WHERE i."ID" = p_ingredient_id
  ) raw
  WHERE n IS NOT NULL AND btrim(n) <> '';

  IF v_names IS NULL OR array_length(v_names, 1) IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT DISTINCT sr.id, sr.recipe_name, sr.image_url
    FROM public.submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
   WHERE sr.status = 'approved'
     AND sr.visibility = 'Public'
     AND lower(btrim(item->>'ingredient')) = ANY(v_names)
   ORDER BY sr.recipe_name
   LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_recipes_using_ingredient(int, int, int) TO anon, authenticated;

-- ── 5. Admin festival search — pagination ───────────────────────────
DROP FUNCTION IF EXISTS public.admin_search_recipes(text, int);
CREATE OR REPLACE FUNCTION public.admin_search_recipes(
  p_query  text DEFAULT '',
  p_limit  int  DEFAULT 24,
  p_offset int  DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 24), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN COALESCE(
    (SELECT jsonb_agg(row_to_json(r) ORDER BY r.recipe_name)
     FROM (
       SELECT id, recipe_name, category, origin_country
       FROM public.submitted_recipes
       WHERE status = 'approved'
         AND (p_query IS NULL OR btrim(p_query) = '' OR recipe_name ILIKE '%' || btrim(p_query) || '%')
       ORDER BY recipe_name
       LIMIT p_limit OFFSET p_offset
     ) r),
    '[]'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_search_recipes(text, int, int) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase42-scale-mitigation ready' AS status;
