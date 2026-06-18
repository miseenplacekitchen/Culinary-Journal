-- fix-pasture-duplicate-offal.sql — Remove mistaken Pasture row (poultry offal belongs under Feather only).
-- Safe to re-run.

UPDATE public.recipe_subcategories
SET is_active = false
WHERE category = 'Pasture & Hoof'
  AND (
    name LIKE '%Poultry Offal%'
    OR name LIKE '🫁%'
  );

SELECT category, name, sort_order, array_length(ingredient_hints, 1) AS hint_count, is_active
FROM public.recipe_subcategories
WHERE category IN ('Feather & Flock', 'Pasture & Hoof') AND is_active = true
ORDER BY category, sort_order;
