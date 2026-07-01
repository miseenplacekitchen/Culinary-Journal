-- fix-dish-index-test-data-repair.sql — Repair drifted TCJ test seed rows (safe, no full re-seed)
-- Run in Supabase when verify check archived_retired_row fails.
-- Does NOT delete or re-insert rows — only fixes known DI9* drift.

-- DI900008 must be archived for queue / export tests
UPDATE public.recipe_name_library
   SET is_active = false,
       content_status = 'retired',
       updated_at = now()
 WHERE dish_code = 'DI900008'
   AND notes LIKE '%[TCJ_TEST_SEED]%'
   AND (COALESCE(is_active, true) <> false OR COALESCE(content_status, '') <> 'retired');

-- DI900009 should keep Tomato-based division for division dropdown / metadata tests
UPDATE public.recipe_name_library
   SET division = 'Tomato-based',
       updated_at = now()
 WHERE dish_code = 'DI900009'
   AND notes LIKE '%[TCJ_TEST_SEED]%'
   AND btrim(COALESCE(division, '')) = '';

SELECT 'fix-dish-index-test-data-repair complete' AS status,
       dish_code,
       is_active,
       content_status,
       division
  FROM public.recipe_name_library
 WHERE dish_code IN ('DI900008', 'DI900009')
   AND notes LIKE '%[TCJ_TEST_SEED]%'
 ORDER BY dish_code;
