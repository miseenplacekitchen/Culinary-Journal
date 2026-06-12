-- fix-garden-v3-polish.sql
-- Live patch AFTER RUN-GARDEN-V3.sql succeeded.
-- Paste garden-v3-06-rpcs.sql first (or this file's companion RUN-GARDEN-V3-POLISH.sql bundle).

-- Re-link tomato hinge via library profile if missing
INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
SELECT p.id, sub.ing_id, 'fruit', true
FROM public.plants p
CROSS JOIN LATERAL (
  SELECT ing_id FROM (
    SELECT lp.governed_ingredient_id AS ing_id, 0 AS pri
    FROM public.library_profiles lp
    WHERE lp.profile_type = 'ingredient' AND lp.slug = 'tomato' AND lp.governed_ingredient_id IS NOT NULL
    UNION ALL
    SELECT i."ID" AS ing_id, 1 AS pri FROM public.ingredients i
    WHERE lower(btrim(i."Ingredient Name")) IN ('tomato', 'tomatoes')
  ) picks ORDER BY pri LIMIT 1
) sub
WHERE p.slug = 'tomato' AND sub.ing_id IS NOT NULL
ON CONFLICT (plant_id, ingredient_id, part) DO NOTHING;

SELECT p.slug, count(pi.id) AS ingredient_links,
  (SELECT lp.slug FROM public.library_profiles lp
   JOIN public.plant_ingredients pi2 ON pi2.ingredient_id = lp.governed_ingredient_id
   WHERE pi2.plant_id = p.id AND lp.profile_type = 'ingredient' LIMIT 1) AS library_slug
FROM public.plants p
LEFT JOIN public.plant_ingredients pi ON pi.plant_id = p.id
WHERE p.slug = 'tomato'
GROUP BY p.id, p.slug;
