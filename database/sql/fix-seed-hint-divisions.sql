-- fix-seed-hint-divisions.sql — Turn ingredient_hints into browse divisions (ingredient forms).
-- Run once after Garden / Feather / Pasture / Ocean / Grain / Sips category seeds.
-- Safe to re-run. Reverses the empty "Divisions coming soon" state from fix-deactivate-legacy-taxonomy.sql.
--
-- Book model: A1/B1 sub-category → divisions = the ingredient forms listed under each sub.

INSERT INTO public.recipe_divisions (
  category, subcategory, name, emoji, subtitle, description, sort_order, is_active
)
SELECT
  sc.category,
  sc.name,
  trim(hint),
  COALESCE(NULLIF(trim(sc.emoji), ''), '🍽'),
  'Ingredient form',
  '',
  (ordinality * 10)::int,
  true
FROM public.recipe_subcategories sc
CROSS JOIN LATERAL unnest(sc.ingredient_hints) WITH ORDINALITY AS t(hint, ordinality)
WHERE sc.is_active = true
  AND sc.ingredient_hints IS NOT NULL
  AND cardinality(sc.ingredient_hints) > 0
  AND trim(hint) <> ''
  AND sc.category IN (
    'Garden & Earth',
    'Feather & Flock',
    'Pasture & Hoof',
    'Ocean & River',
    'The Grain Field',
    'Sips & Stories'
  )
ON CONFLICT (category, subcategory, name) DO UPDATE SET
  sort_order = EXCLUDED.sort_order,
  is_active = true,
  emoji = EXCLUDED.emoji,
  subtitle = EXCLUDED.subtitle;

SELECT category, subcategory, count(*) AS division_count
FROM public.recipe_divisions
WHERE is_active = true
  AND category IN (
    'Garden & Earth', 'Feather & Flock', 'Pasture & Hoof',
    'Ocean & River', 'The Grain Field', 'Sips & Stories'
  )
GROUP BY category, subcategory
ORDER BY category, subcategory;
