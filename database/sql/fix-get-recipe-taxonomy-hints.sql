-- fix-get-recipe-taxonomy-hints.sql — Superseded by fix-admin-taxonomy-editor.sql (2026).
-- Run fix-admin-taxonomy-editor.sql instead (includes ingredient_hints + sub copy fields).

-- If you only need the minimal hints patch and cannot run the full editor file yet:
DROP FUNCTION IF EXISTS public.get_recipe_taxonomy(text);
CREATE OR REPLACE FUNCTION public.get_recipe_taxonomy(p_category text DEFAULT NULL)
RETURNS TABLE (
  subcategory_id uuid, subcategory_name text, subcategory_category text,
  subcategory_sort_order int,
  subcategory_emoji text,
  subcategory_tagline text,
  subcategory_description text,
  subcategory_ingredient_hints text[],
  division_id uuid, division_name text, division_emoji text,
  division_subtitle text, division_description text,
  division_sort_order int
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT sc.id, sc.name, sc.category, sc.sort_order, sc.emoji, sc.tagline, sc.description, sc.ingredient_hints,
         d.id, d.name, d.emoji, d.subtitle, d.description, d.sort_order
    FROM public.recipe_subcategories sc
    LEFT JOIN public.recipe_divisions d
      ON d.category = sc.category AND d.subcategory = sc.name AND d.is_active = true
   WHERE sc.is_active = true
     AND (p_category IS NULL OR sc.category = p_category)
   ORDER BY sc.category, sc.sort_order, sc.name, d.sort_order, d.name;
$$;
REVOKE ALL ON FUNCTION public.get_recipe_taxonomy(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recipe_taxonomy(text) TO anon, authenticated;
