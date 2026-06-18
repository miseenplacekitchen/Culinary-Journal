-- migrate-feast-nourish-categories.sql
-- Move legacy main-category values into tags + a real book category (A–L).
-- Feast Days  → occasion_tags + Slow & Soulful (or meal-type guess)
-- Nourish & Heal → health/dietary tags preserved + Garden & Earth (or meal-type guess)
-- Run once after fix-recipe-discovery-rpcs.sql. Review counts at the end.

-- ── Feast Days ───────────────────────────────────────────────────────────────
UPDATE public.submitted_recipes sr
SET occasion_tags = (
  SELECT ARRAY(
    SELECT DISTINCT unnest(
      COALESCE(sr.occasion_tags, '{}') ||
      CASE WHEN sr.recipe_name ILIKE '%onam%' OR sr.recipe_name ILIKE '%sadya%' OR sr.recipe_name ILIKE '%payasam%' THEN ARRAY['Onam'] ELSE '{}' END ||
      CASE WHEN sr.recipe_name ILIKE '%eid%' THEN ARRAY['Eid'] ELSE '{}' END ||
      CASE WHEN sr.recipe_name ILIKE '%christmas%' OR sr.recipe_name ILIKE '%xmas%' THEN ARRAY['Christmas'] ELSE '{}' END ||
      CASE WHEN sr.recipe_name ILIKE '%diwali%' OR sr.recipe_name ILIKE '%deepavali%' THEN ARRAY['Diwali'] ELSE '{}' END ||
      CASE WHEN cardinality(COALESCE(sr.occasion_tags, '{}')) = 0 THEN ARRAY['Party'] ELSE '{}' END
    )
  )
)
WHERE sr.category = 'Feast Days';

UPDATE public.submitted_recipes
SET category = CASE
  WHEN 'Dessert' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Sweet Serenades'
  WHEN 'Rice Dish' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Grains & Comfort'
  WHEN 'Bread' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Breads & Bakes'
  WHEN 'Drink' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Sips & Stories'
  WHEN 'Preserve / Pickle' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Preserved & Cherished'
  ELSE 'Slow & Soulful'
END
WHERE category = 'Feast Days';

-- ── Nourish & Heal ───────────────────────────────────────────────────────────
UPDATE public.submitted_recipes
SET category = CASE
  WHEN 'Dessert' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Sweet Serenades'
  WHEN 'Drink' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Sips & Stories'
  WHEN 'Bread' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Breads & Bakes'
  WHEN 'Rice Dish' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Grains & Comfort'
  WHEN 'Soup' = ANY(COALESCE(meal_type_tags, '{}')) THEN 'Slow & Soulful'
  ELSE 'Garden & Earth'
END
WHERE category = 'Nourish & Heal';

SELECT 'legacy category counts' AS report,
  (SELECT count(*) FROM public.submitted_recipes WHERE category = 'Feast Days') AS feast_days_left,
  (SELECT count(*) FROM public.submitted_recipes WHERE category = 'Nourish & Heal') AS nourish_heal_left,
  (SELECT count(*) FROM public.submitted_recipes WHERE 'Party' = ANY(COALESCE(occasion_tags, '{}'))) AS with_party_occasion,
  (SELECT count(*) FROM public.submitted_recipes WHERE cardinality(COALESCE(health_tags, '{}')) > 0) AS with_health_tags;
