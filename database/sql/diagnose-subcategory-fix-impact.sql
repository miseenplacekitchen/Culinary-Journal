-- Audit impact of fix-subcategory-categories.sql
-- Run in Supabase SQL Editor.

-- 1. Active subs per category NOW
SELECT COUNT(*) AS total_active, category
FROM public.recipe_subcategories
WHERE is_active = true
GROUP BY category
ORDER BY category;

-- 2. Grand total active vs inactive
SELECT
  COUNT(*) FILTER (WHERE is_active = true) AS active_total,
  COUNT(*) FILTER (WHERE is_active = false) AS inactive_total,
  COUNT(*) AS all_rows
FROM public.recipe_subcategories;

-- 3. Rows deactivated (still in DB, hidden from browse/admin RPC)
SELECT category, COUNT(*) AS deactivated_count
FROM public.recipe_subcategories
WHERE is_active = false
GROUP BY category
ORDER BY deactivated_count DESC, category;

-- 4. Legacy short names NOT in the 246-name book mapping (never updated by fix script)
SELECT name, category, is_active
FROM public.recipe_subcategories
WHERE name IN ('Beef', 'Lamb', 'Poultry', 'Chicken', 'Pork', 'Mutton', 'Goat')
ORDER BY is_active DESC, name, category;

-- 5. Duplicate names: same sub name in multiple categories (fix step 3 targets these)
SELECT name, COUNT(*) AS row_count,
       array_agg(category ORDER BY category) AS categories,
       array_agg(is_active ORDER BY category) AS active_flags
FROM public.recipe_subcategories
GROUP BY name
HAVING COUNT(*) > 1
ORDER BY name;

-- 6. Misassigned active subs (re-run tail of fix-subcategory-categories.sql mapping check)
--    Paste the tcj_sub_category_fix INSERT from that file, or run section 6 there after a fresh session.
--    Quick spot-check: active subs on legacy category names
SELECT name, category
FROM public.recipe_subcategories
WHERE is_active = true
  AND category IN ('Meat & Fire', 'Slow & Soulful', 'Grains & Comfort', 'Rise & Shine',
                   'The Evening Table', 'Breads & Bakes', 'Preserved & Cherished', 'Vegetables')
ORDER BY category, name;
