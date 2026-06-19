-- fix-get-recipe-taxonomy-active-only.sql
-- Ensures get_recipe_taxonomy returns ONLY active subcategories + active divisions.
-- Run once in Supabase SQL Editor. Safe to re-run.
--
-- Admin Taxonomy tab calls: rpc('get_recipe_taxonomy', { p_category: null })

DROP FUNCTION IF EXISTS public.get_recipe_taxonomy(text);
CREATE OR REPLACE FUNCTION public.get_recipe_taxonomy(p_category text DEFAULT NULL)
RETURNS TABLE (
  subcategory_id uuid,
  subcategory_name text,
  subcategory_category text,
  subcategory_sort_order int,
  subcategory_emoji text,
  subcategory_tagline text,
  subcategory_description text,
  subcategory_ingredient_hints text[],
  division_id uuid,
  division_name text,
  division_emoji text,
  division_subtitle text,
  division_description text,
  division_sort_order int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT sc.id, sc.name, sc.category, sc.sort_order, sc.emoji, sc.tagline, sc.description, sc.ingredient_hints,
         d.id, d.name, d.emoji, d.subtitle, d.description, d.sort_order
    FROM public.recipe_subcategories sc
    LEFT JOIN public.recipe_divisions d
      ON d.category = sc.category
     AND d.subcategory = sc.name
     AND COALESCE(d.is_active, false) = true
   WHERE COALESCE(sc.is_active, false) = true
     AND (p_category IS NULL OR sc.category = p_category)
   ORDER BY sc.category, sc.sort_order, sc.name, d.sort_order, d.name;
$$;
REVOKE ALL ON FUNCTION public.get_recipe_taxonomy(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recipe_taxonomy(text) TO anon, authenticated;

-- ── Verify: inactive subs must NOT appear in RPC ─────────────────────────────
SELECT sc.id, sc.name, sc.category, sc.is_active
FROM public.recipe_subcategories sc
WHERE COALESCE(sc.is_active, false) = false
  AND EXISTS (
    SELECT 1 FROM public.get_recipe_taxonomy(NULL) r
    WHERE r.subcategory_id = sc.id
  );
-- Expected: 0 rows

-- Count check
SELECT
  (SELECT COUNT(*) FROM public.recipe_subcategories WHERE COALESCE(is_active, false) = true) AS active_subs_in_table,
  (SELECT COUNT(DISTINCT subcategory_id) FROM public.get_recipe_taxonomy(NULL)) AS active_subs_in_rpc;
