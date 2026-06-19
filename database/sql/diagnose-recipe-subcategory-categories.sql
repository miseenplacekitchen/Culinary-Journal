-- List active subcategories and their DB category column (for misassignment audit).
-- Run in Supabase SQL Editor.

SELECT name, category
FROM public.recipe_subcategories
WHERE is_active = true
ORDER BY category, name;
