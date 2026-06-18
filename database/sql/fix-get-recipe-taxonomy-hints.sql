-- fix-get-recipe-taxonomy-hints.sql — Re-run if v3 was applied after fix-garden-taxonomy-v2.sql.
-- Restores subcategory_ingredient_hints on get_recipe_taxonomy (safe to re-run).

DROP FUNCTION IF EXISTS public.get_recipe_taxonomy(text);
CREATE OR REPLACE FUNCTION public.get_recipe_taxonomy(p_category text DEFAULT NULL)
RETURNS TABLE (
  subcategory_id uuid, subcategory_name text, subcategory_category text,
  subcategory_ingredient_hints text[],
  division_id uuid, division_name text, division_emoji text,
  division_subtitle text, division_description text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT sc.id, sc.name, sc.category, sc.ingredient_hints,
         d.id, d.name, d.emoji, d.subtitle, d.description
    FROM public.recipe_subcategories sc
    LEFT JOIN public.recipe_divisions d
      ON d.category = sc.category AND d.subcategory = sc.name AND d.is_active = true
   WHERE sc.is_active = true
     AND (p_category IS NULL OR sc.category = p_category)
   ORDER BY sc.category, sc.sort_order, sc.name, d.sort_order, d.name;
$$;
REVOKE ALL ON FUNCTION public.get_recipe_taxonomy(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recipe_taxonomy(text) TO anon, authenticated;
