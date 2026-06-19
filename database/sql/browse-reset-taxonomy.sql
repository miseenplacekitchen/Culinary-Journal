-- STEP 1: Clear browse taxonomy rows (keeps public.categories intact).
-- Run once in Supabase SQL Editor before testing the browse overhaul.

DELETE FROM public.recipe_divisions;
DELETE FROM public.recipe_subcategories;

SELECT 'recipe_subcategories' AS table_name, COUNT(*) AS count FROM public.recipe_subcategories
UNION ALL
SELECT 'recipe_divisions', COUNT(*) FROM public.recipe_divisions
UNION ALL
SELECT 'categories', COUNT(*) FROM public.categories;
