-- ══════════════════════════════════════════════════════════════════════
-- fix-phase25-library-links-patch.sql
-- Links starter profiles that missed exact name match (butter, rice, salt, tomato).
-- Safe to re-run. Run after fix-phase25-library-starter.sql
-- ══════════════════════════════════════════════════════════════════════

-- Optional: see what names exist in your governed DB
SELECT "ID", "Ingredient Name"
FROM public.ingredients
WHERE lower("Ingredient Name") LIKE '%butter%'
   OR lower("Ingredient Name") LIKE '%rice%'
   OR lower("Ingredient Name") LIKE '%salt%'
   OR lower("Ingredient Name") LIKE '%tomato%'
ORDER BY "Ingredient Name";

-- Butter (exclude peanut butter, cocoa butter, etc.)
UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%butter%'
    AND lower("Ingredient Name") NOT LIKE '%peanut%'
    AND lower("Ingredient Name") NOT LIKE '%cocoa%'
    AND lower("Ingredient Name") NOT LIKE '%almond%'
    AND lower("Ingredient Name") NOT LIKE '%nutella%'
  ORDER BY
    CASE WHEN lower(trim("Ingredient Name")) = 'butter' THEN 0
         WHEN lower("Ingredient Name") LIKE 'butter%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'butter' AND (ip.governed_ingredient_id IS NULL OR ip.governed_ingredient_id <> sub.ing_id);

-- Rice (prefer plain "rice" or short names)
UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%rice%'
    AND lower("Ingredient Name") NOT LIKE '%rice paper%'
    AND lower("Ingredient Name") NOT LIKE '%rice wine%'
    AND lower("Ingredient Name") NOT LIKE '%rice vinegar%'
    AND lower("Ingredient Name") NOT LIKE '%rice flour%'
    AND lower("Ingredient Name") NOT LIKE '%rice noodle%'
    AND lower("Ingredient Name") NOT LIKE '%rice syrup%'
  ORDER BY
    CASE WHEN lower(trim("Ingredient Name")) = 'rice' THEN 0
         WHEN lower("Ingredient Name") LIKE 'rice,%' THEN 1
         WHEN lower("Ingredient Name") LIKE 'rice %' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'rice' AND (ip.governed_ingredient_id IS NULL OR ip.governed_ingredient_id <> sub.ing_id);

-- Salt (table / sea / fine — not celery salt, etc. unless only option)
UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%salt%'
    AND lower("Ingredient Name") NOT LIKE '%celery%'
    AND lower("Ingredient Name") NOT LIKE '%garlic salt%'
    AND lower("Ingredient Name") NOT LIKE '%onion salt%'
    AND lower("Ingredient Name") NOT LIKE '%seasoning%'
    AND lower("Ingredient Name") NOT LIKE '%epsom%'
  ORDER BY
    CASE WHEN lower(trim("Ingredient Name")) = 'salt' THEN 0
         WHEN lower("Ingredient Name") LIKE 'salt,%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%table salt%' THEN 2
         WHEN lower("Ingredient Name") LIKE '%sea salt%' THEN 3
         ELSE 4 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'salt' AND (ip.governed_ingredient_id IS NULL OR ip.governed_ingredient_id <> sub.ing_id);

-- Tomato (fresh — not paste, sauce, sun-dried unless only option)
UPDATE public.ingredient_profiles ip SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower("Ingredient Name") LIKE '%tomato%'
    AND lower("Ingredient Name") NOT LIKE '%paste%'
    AND lower("Ingredient Name") NOT LIKE '%sauce%'
    AND lower("Ingredient Name") NOT LIKE '%ketchup%'
    AND lower("Ingredient Name") NOT LIKE '%sun-dried%'
    AND lower("Ingredient Name") NOT LIKE '%sundried%'
    AND lower("Ingredient Name") NOT LIKE '%canned%'
    AND lower("Ingredient Name") NOT LIKE '%tinned%'
    AND lower("Ingredient Name") NOT LIKE '%puree%'
    AND lower("Ingredient Name") NOT LIKE '%purée%'
  ORDER BY
    CASE WHEN lower(trim("Ingredient Name")) IN ('tomato', 'tomatoes') THEN 0
         WHEN lower("Ingredient Name") LIKE 'tomato,%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%fresh tomato%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE ip.slug = 'tomato' AND (ip.governed_ingredient_id IS NULL OR ip.governed_ingredient_id <> sub.ing_id);

SELECT slug, name, governed_ingredient_id, status
FROM public.ingredient_profiles
WHERE slug IN ('garlic','onion','butter','olive-oil','rice','tomato','chicken-breast','salt')
ORDER BY slug;
