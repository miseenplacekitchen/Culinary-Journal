-- Run in Supabase SQL Editor to check TCJ taxonomy (correct table names).
-- Do NOT run external dev SQL that references recipes / subcategories / divisions.

SELECT 'categories' AS table_name, COUNT(*) AS count FROM public.categories
UNION ALL
SELECT 'recipe_subcategories', COUNT(*) FROM public.recipe_subcategories WHERE is_active = true
UNION ALL
SELECT 'recipe_divisions', COUNT(*) FROM public.recipe_divisions WHERE is_active = true
UNION ALL
SELECT 'submitted_recipes', COUNT(*) FROM public.submitted_recipes;

SELECT routine_name FROM information_schema.routines
 WHERE routine_schema = 'public'
   AND routine_name IN (
     'get_recipe_taxonomy',
     'admin_get_recipes_bulk',
     'admin_update_recipe_field',
     'admin_bulk_assign_recipe_taxonomy'
   )
 ORDER BY routine_name;
