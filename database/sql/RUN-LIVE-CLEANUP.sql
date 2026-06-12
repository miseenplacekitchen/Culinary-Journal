-- =============================================================================
-- THE CULINARY JOURNAL — LIVE CLEANUP (run in Supabase SQL Editor)
-- Run this entire file on production AFTER deploying site code.
-- Order: library links -> health RPCs -> verification.
-- Safe to re-run. Expect final health_report.healthy = true.
-- =============================================================================


-- ########## BEGIN: fix-library-governed-links.sql ##########
-- fix-library-governed-links.sql
-- Re-link starter library profiles to the best governed ingredient match per slug.
-- Uses fuzzy rules (like fix-phase25-library-links-patch), not hardcoded display names.
-- Prefer RUN-LIVE-CLEANUP.sql (library links + phase43 health RPCs + verification).

-- Preview current links
SELECT lp.slug, lp.name AS profile_name, lp.governed_ingredient_id,
       gi."Ingredient Name" AS governed_name
FROM library_profiles lp
LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
WHERE lp.profile_type = 'ingredient'
  AND lp.slug IN (
    'garlic','onion','butter','rice','tomato','chicken-breast','salt','lemon',
    'ginger','egg','flour','potato','coconut','milk','capsicum','olive-oil'
  )
ORDER BY lp.slug;

-- garlic
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower(btrim("Ingredient Name")) = 'garlic'
     OR lower("Ingredient Name") LIKE 'garlic,%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'garlic' THEN 0 ELSE 1 END,
    "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'garlic';

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

-- chicken-breast
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%chicken%'
    AND lower("Ingredient Name") LIKE '%breast%'
    AND lower("Ingredient Name") NOT LIKE '%ground%'
    AND lower("Ingredient Name") NOT LIKE '%mince%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) LIKE '%chicken breast%' THEN 0 ELSE 1 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'chicken-breast';

-- lemon
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%lemon%'
    AND lower("Ingredient Name") NOT LIKE '%juice%'
    AND lower("Ingredient Name") NOT LIKE '%zest%'
    AND lower("Ingredient Name") NOT LIKE '%grass%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) IN ('lemon', 'lemons') THEN 0 ELSE 1 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'lemon';

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

-- Verify all ingredient library profiles (not just starter slugs)
SELECT lp.slug, lp.name AS profile_name, lp.governed_ingredient_id,
       gi."Ingredient Name" AS governed_name,
       CASE
         WHEN lp.governed_ingredient_id IS NULL THEN 'MISSING LINK'
         WHEN gi."Ingredient Name" IS NULL THEN 'MISSING LINK'
         WHEN lower(btrim(lp.name)) <> lower(btrim(gi."Ingredient Name")) THEN 'NAME MISMATCH'
         WHEN lower(gi."Ingredient Name") LIKE '%buttermilk%' AND lp.slug = 'butter' THEN 'WRONG LINK'
         WHEN lower(gi."Ingredient Name") LIKE '%peanut butter%' AND lp.slug = 'butter' THEN 'WRONG LINK'
         WHEN lower(gi."Ingredient Name") LIKE '%rice paper%' AND lp.slug = 'rice' THEN 'WRONG LINK'
         WHEN lower(gi."Ingredient Name") LIKE '%buttermilk%' AND lp.slug = 'milk' THEN 'WRONG LINK'
         ELSE 'ok'
       END AS link_status
FROM library_profiles lp
LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
WHERE lp.profile_type = 'ingredient'
ORDER BY lp.slug;

-- Single summary (Supabase often shows only the last result)
SELECT jsonb_build_object(
  'status', 'fix-library-governed-links ready',
  'profiles_checked', count(*),
  'all_ok', count(*) FILTER (WHERE link_status = 'ok'),
  'problems', COALESCE(jsonb_agg(jsonb_build_object(
    'slug', slug, 'profile_name', profile_name, 'governed_name', governed_name, 'link_status', link_status
  ) ORDER BY slug) FILTER (WHERE link_status <> 'ok'), '[]'::jsonb)
) AS library_link_summary
FROM (
  SELECT lp.slug, lp.name AS profile_name,
         gi."Ingredient Name" AS governed_name,
         CASE
           WHEN lp.governed_ingredient_id IS NULL THEN 'MISSING LINK'
           WHEN gi."Ingredient Name" IS NULL THEN 'MISSING LINK'
           WHEN lower(btrim(lp.name)) <> lower(btrim(gi."Ingredient Name")) THEN 'NAME MISMATCH'
           WHEN lower(gi."Ingredient Name") LIKE '%buttermilk%' AND lp.slug = 'butter' THEN 'WRONG LINK'
           WHEN lower(gi."Ingredient Name") LIKE '%peanut butter%' AND lp.slug = 'butter' THEN 'WRONG LINK'
           WHEN lower(gi."Ingredient Name") LIKE '%rice paper%' AND lp.slug = 'rice' THEN 'WRONG LINK'
           WHEN lower(gi."Ingredient Name") LIKE '%buttermilk%' AND lp.slug = 'milk' THEN 'WRONG LINK'
           ELSE 'ok'
         END AS link_status
  FROM library_profiles lp
  LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
) v;
-- ########## END: fix-library-governed-links.sql ##########

-- ########## BEGIN: fix-phase43-starter-library-health.sql ##########
-- fix-phase43-starter-library-health.sql
-- Align dashboard + SQL editor health checks with starter wrong-link detection.
-- Safe to re-run.

CREATE OR REPLACE FUNCTION public.admin_data_integrity_report()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invalid_governed int;
  v_name_mismatch int;
  v_wrong_starter int;
  v_dupes int;
  v_orphan_recipe_names int;
  v_total_recipes int;
  v_approved_recipes int;
  v_total_ingredients int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  SELECT count(*)::int INTO v_total_recipes FROM submitted_recipes;
  SELECT count(*)::int INTO v_approved_recipes FROM submitted_recipes WHERE status = 'approved';
  SELECT count(*)::int INTO v_total_ingredients FROM ingredients;

  SELECT count(*)::int INTO v_invalid_governed
  FROM library_profiles lp
  WHERE lp.profile_type = 'ingredient'
    AND lp.governed_ingredient_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i."ID" = lp.governed_ingredient_id);

  SELECT count(*)::int INTO v_name_mismatch
  FROM library_profiles lp
  JOIN ingredients i ON i."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"));

  SELECT count(*)::int INTO v_wrong_starter
  FROM library_profiles lp
  JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND (
      (lp.slug = 'butter' AND (
        lower(gi."Ingredient Name") LIKE '%buttermilk%'
        OR lower(gi."Ingredient Name") LIKE '%peanut butter%'
      ))
      OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
      OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
    );

  SELECT count(*)::int INTO v_dupes
  FROM (
    SELECT lower(btrim("Ingredient Name")) AS n
    FROM ingredients
    WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
    GROUP BY 1 HAVING count(*) > 1
  ) d;

  SELECT count(DISTINCT x.ing_name)::int INTO v_orphan_recipe_names
  FROM (
    SELECT lower(btrim(item->>'ingredient')) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
  );

  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'recipes', v_total_recipes,
      'approved_recipes', v_approved_recipes,
      'ingredients', v_total_ingredients
    ),
    'issues', jsonb_build_object(
      'invalid_governed_links', v_invalid_governed,
      'library_name_mismatches', v_name_mismatch,
      'starter_library_wrong_links', v_wrong_starter,
      'duplicate_ingredient_names', v_dupes,
      'orphan_recipe_ingredient_names', v_orphan_recipe_names
    ),
    'healthy', (
      v_invalid_governed = 0
      AND v_name_mismatch = 0
      AND v_wrong_starter = 0
      AND v_dupes = 0
      AND v_orphan_recipe_names = 0
    )
  );
END; $$;

REVOKE ALL ON FUNCTION public.admin_data_integrity_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_data_integrity_report() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_data_integrity_report_sql()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invalid_governed int;
  v_name_mismatch int;
  v_wrong_starter int;
  v_dupes int;
  v_orphan_recipe_names int;
  v_total_recipes int;
  v_approved_recipes int;
  v_total_ingredients int;
BEGIN
  IF current_user NOT IN ('postgres', 'supabase_admin', 'service_role')
     AND (auth.uid() IS NULL OR NOT is_admin()) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT count(*)::int INTO v_total_recipes FROM submitted_recipes;
  SELECT count(*)::int INTO v_approved_recipes FROM submitted_recipes WHERE status = 'approved';
  SELECT count(*)::int INTO v_total_ingredients FROM ingredients;

  SELECT count(*)::int INTO v_invalid_governed
  FROM library_profiles lp
  WHERE lp.profile_type = 'ingredient'
    AND lp.governed_ingredient_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i."ID" = lp.governed_ingredient_id);

  SELECT count(*)::int INTO v_name_mismatch
  FROM library_profiles lp
  JOIN ingredients i ON i."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"));

  SELECT count(*)::int INTO v_wrong_starter
  FROM library_profiles lp
  JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND (
      (lp.slug = 'butter' AND (
        lower(gi."Ingredient Name") LIKE '%buttermilk%'
        OR lower(gi."Ingredient Name") LIKE '%peanut butter%'
      ))
      OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
      OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
    );

  SELECT count(*)::int INTO v_dupes
  FROM (
    SELECT lower(btrim("Ingredient Name")) AS n
    FROM ingredients
    WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
    GROUP BY 1 HAVING count(*) > 1
  ) d;

  SELECT count(DISTINCT x.ing_name)::int INTO v_orphan_recipe_names
  FROM (
    SELECT lower(btrim(item->>'ingredient')) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
  );

  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'recipes', v_total_recipes,
      'approved_recipes', v_approved_recipes,
      'ingredients', v_total_ingredients
    ),
    'issues', jsonb_build_object(
      'invalid_governed_links', v_invalid_governed,
      'library_name_mismatches', v_name_mismatch,
      'starter_library_wrong_links', v_wrong_starter,
      'duplicate_ingredient_names', v_dupes,
      'orphan_recipe_ingredient_names', v_orphan_recipe_names
    ),
    'healthy', (
      v_invalid_governed = 0
      AND v_name_mismatch = 0
      AND v_wrong_starter = 0
      AND v_dupes = 0
      AND v_orphan_recipe_names = 0
    )
  );
END; $$;

REVOKE ALL ON FUNCTION public.admin_data_integrity_report_sql() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_data_integrity_report_sql() TO postgres, service_role;

SELECT 'fix-phase43-starter-library-health ready' AS status;
-- ########## END: fix-phase43-starter-library-health.sql ##########

-- ########## BEGIN: SQL-EDITOR-health-check.sql ##########
-- =============================================================================
-- RUN IN SUPABASE SQL EDITOR (no login required)
-- Copy all → paste → Run. Turn OFF "limit 100" if Supabase shows that option.
-- Or run RUN-LIVE-CLEANUP.sql for the full live sequence.
-- =============================================================================

SELECT jsonb_build_object(
  'totals', jsonb_build_object(
    'recipes', (SELECT count(*)::int FROM public.submitted_recipes),
    'approved_recipes', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
    'ingredients', (SELECT count(*)::int FROM public.ingredients)
  ),
  'issues', jsonb_build_object(
    'invalid_governed_links', (
      SELECT count(*)::int FROM public.library_profiles lp
      WHERE lp.profile_type = 'ingredient'
        AND lp.governed_ingredient_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id
        )
    ),
    'library_name_mismatches', (
      SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients i ON i."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"))
    ),
    'duplicate_ingredient_names', (
      SELECT count(*)::int FROM (
        SELECT lower(btrim("Ingredient Name")) AS n
        FROM public.ingredients
        WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
        GROUP BY 1 HAVING count(*) > 1
      ) d
    ),
    'starter_library_wrong_links', (
      SELECT count(*)::int
      FROM public.library_profiles lp
      JOIN public.ingredients gi ON gi."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND (
          (lp.slug = 'butter' AND (
            lower(gi."Ingredient Name") LIKE '%buttermilk%'
            OR lower(gi."Ingredient Name") LIKE '%peanut butter%'
          ))
          OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
          OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
        )
    ),
    'orphan_recipe_ingredient_names', (
      SELECT count(DISTINCT x.ing_name)::int
      FROM (
        SELECT lower(btrim(item->>'ingredient')) AS ing_name
        FROM public.submitted_recipes sr,
             jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE sr.status = 'approved'
          AND btrim(COALESCE(item->>'ingredient', '')) <> ''
      ) x
      WHERE NOT EXISTS (
        SELECT 1 FROM public.ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
           OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
      )
    )
  ),
  'healthy', (
    (SELECT count(*)::int FROM public.library_profiles lp
      WHERE lp.profile_type = 'ingredient'
        AND lp.governed_ingredient_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id)
    ) = 0
    AND (SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients i ON i."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"))
    ) = 0
    AND (SELECT count(*)::int FROM (
      SELECT lower(btrim("Ingredient Name")) AS n FROM public.ingredients
      WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
      GROUP BY 1 HAVING count(*) > 1
    ) d) = 0
    AND (SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients gi ON gi."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND (
          (lp.slug = 'butter' AND (lower(gi."Ingredient Name") LIKE '%buttermilk%' OR lower(gi."Ingredient Name") LIKE '%peanut butter%'))
          OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
          OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
        )
    ) = 0
    AND (SELECT count(DISTINCT x.ing_name)::int
      FROM (
        SELECT lower(btrim(item->>'ingredient')) AS ing_name
        FROM public.submitted_recipes sr,
             jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE sr.status = 'approved' AND btrim(COALESCE(item->>'ingredient', '')) <> ''
      ) x
      WHERE NOT EXISTS (
        SELECT 1 FROM public.ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
           OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
      )
    ) = 0
  )
) AS health_report;
-- ########## END: SQL-EDITOR-health-check.sql ##########
