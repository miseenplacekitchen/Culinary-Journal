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
    SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR EXISTS (
         SELECT 1
         FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
         WHERE btrim(aka.part) = x.ing_name
       )
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
    SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR EXISTS (
         SELECT 1
         FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
         WHERE btrim(aka.part) = x.ing_name
       )
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
