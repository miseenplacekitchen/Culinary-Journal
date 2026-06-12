-- fix-library-governed-links.sql
-- Re-link starter library profiles to the best governed ingredient match per slug.
-- Uses fuzzy rules (like fix-phase25-library-links-patch), not hardcoded display names.
-- Run in Supabase SQL Editor, then: SQL-EDITOR-health-check.sql

-- Preview current links
SELECT lp.slug, lp.name AS profile_name, lp.governed_ingredient_id,
       gi."Ingredient Name" AS governed_name
FROM library_profiles lp
LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
WHERE lp.profile_type = 'ingredient'
  AND lp.slug IN (
    'salt','onion','butter','rice','tomato','ginger','egg','flour',
    'potato','coconut','milk','capsicum','olive-oil'
  )
ORDER BY lp.slug;

-- butter
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%butter%'
    AND lower("Ingredient Name") NOT LIKE '%peanut%'
    AND lower("Ingredient Name") NOT LIKE '%cocoa%'
    AND lower("Ingredient Name") NOT LIKE '%almond%'
    AND lower("Ingredient Name") NOT LIKE '%buttermilk%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'butter' THEN 0
         WHEN lower("Ingredient Name") LIKE 'butter%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%unsalted butter%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'butter';

-- rice
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%rice%'
    AND lower("Ingredient Name") NOT LIKE '%rice paper%'
    AND lower("Ingredient Name") NOT LIKE '%rice wine%'
    AND lower("Ingredient Name") NOT LIKE '%rice vinegar%'
    AND lower("Ingredient Name") NOT LIKE '%rice flour%'
    AND lower("Ingredient Name") NOT LIKE '%rice noodle%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'rice' THEN 0
         WHEN lower("Ingredient Name") LIKE 'rice,%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%basmati%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'rice';

-- salt
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%salt%'
    AND lower("Ingredient Name") NOT LIKE '%celery%'
    AND lower("Ingredient Name") NOT LIKE '%garlic salt%'
    AND lower("Ingredient Name") NOT LIKE '%onion salt%'
    AND lower("Ingredient Name") NOT LIKE '%seasoning%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'salt' THEN 0
         WHEN lower("Ingredient Name") LIKE '%sea salt%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%table salt%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'salt';

-- onion
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%onion%'
    AND lower("Ingredient Name") NOT LIKE '%onion powder%'
    AND lower("Ingredient Name") NOT LIKE '%onion salt%'
    AND lower("Ingredient Name") NOT LIKE '%spring onion%'
    AND lower("Ingredient Name") NOT LIKE '%green onion%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) IN ('onion','onions') THEN 0
         WHEN lower("Ingredient Name") LIKE '%brown onion%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%yellow onion%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'onion';

-- tomato
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%tomato%'
    AND lower("Ingredient Name") NOT LIKE '%paste%'
    AND lower("Ingredient Name") NOT LIKE '%sauce%'
    AND lower("Ingredient Name") NOT LIKE '%ketchup%'
    AND lower("Ingredient Name") NOT LIKE '%puree%'
    AND lower("Ingredient Name") NOT LIKE '%purée%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) IN ('tomato','tomatoes') THEN 0
         WHEN lower("Ingredient Name") LIKE '%roma%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'tomato';

-- ginger
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%ginger%'
    AND lower("Ingredient Name") NOT LIKE '%powder%'
    AND lower("Ingredient Name") NOT LIKE '%ground%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'ginger' THEN 0
         WHEN lower("Ingredient Name") LIKE '%fresh ginger%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'ginger';

-- egg
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%egg%'
    AND lower("Ingredient Name") NOT LIKE '%eggplant%'
    AND lower("Ingredient Name") NOT LIKE '%egg white%'
    AND lower("Ingredient Name") NOT LIKE '%egg yolk%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) IN ('egg','eggs') THEN 0 ELSE 1 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'egg';

-- flour
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%flour%'
    AND lower("Ingredient Name") NOT LIKE '%rice flour%'
    AND lower("Ingredient Name") NOT LIKE '%almond flour%'
    AND lower("Ingredient Name") NOT LIKE '%coconut flour%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%plain flour%' THEN 0
         WHEN lower(btrim("Ingredient Name")) = 'flour' THEN 1
         WHEN lower("Ingredient Name") LIKE '%all purpose%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'flour';

-- potato
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%potato%'
    AND lower("Ingredient Name") NOT LIKE '%sweet potato%'
    AND lower("Ingredient Name") NOT LIKE '%potato starch%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'potato' THEN 0
         WHEN lower("Ingredient Name") LIKE '%sebago%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'potato';

-- coconut
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%coconut%'
    AND lower("Ingredient Name") NOT LIKE '%coconut oil%'
    AND lower("Ingredient Name") NOT LIKE '%coconut milk%'
    AND lower("Ingredient Name") NOT LIKE '%coconut cream%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%desiccated%' THEN 0
         WHEN lower(btrim("Ingredient Name")) = 'coconut' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'coconut';

-- milk
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%milk%'
    AND lower("Ingredient Name") NOT LIKE '%coconut milk%'
    AND lower("Ingredient Name") NOT LIKE '%almond milk%'
    AND lower("Ingredient Name") NOT LIKE '%oat milk%'
    AND lower("Ingredient Name") NOT LIKE '%condensed%'
    AND lower("Ingredient Name") NOT LIKE '%evaporated%'
    AND lower("Ingredient Name") NOT LIKE '%buttermilk%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'milk' THEN 0
         WHEN lower("Ingredient Name") LIKE '%full cream%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'milk';

-- capsicum
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%capsicum%'
     OR lower("Ingredient Name") LIKE '%bell pepper%'
     OR lower("Ingredient Name") LIKE '%red pepper%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%red capsicum%' THEN 0
         WHEN lower("Ingredient Name") LIKE '%capsicum%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'capsicum';

-- olive-oil
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%olive oil%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%extra virgin%' THEN 0
         WHEN lower(btrim("Ingredient Name")) = 'olive oil' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'olive-oil';

-- Verify: NULL governed_id or still pointing at buttermilk etc. is a problem
SELECT lp.slug, lp.name AS profile_name, lp.governed_ingredient_id,
       gi."Ingredient Name" AS governed_name,
       CASE
         WHEN lp.governed_ingredient_id IS NULL THEN 'MISSING LINK'
         WHEN lower(gi."Ingredient Name") LIKE '%buttermilk%' AND lp.slug = 'butter' THEN 'WRONG LINK'
         WHEN lower(gi."Ingredient Name") LIKE '%peanut butter%' AND lp.slug = 'butter' THEN 'WRONG LINK'
         ELSE 'ok'
       END AS link_status
FROM library_profiles lp
LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
WHERE lp.profile_type = 'ingredient'
  AND lp.slug IN (
    'salt','onion','butter','rice','tomato','ginger','egg','flour',
    'potato','coconut','milk','capsicum','olive-oil'
  )
ORDER BY lp.slug;

SELECT 'fix-library-governed-links ready' AS status;
