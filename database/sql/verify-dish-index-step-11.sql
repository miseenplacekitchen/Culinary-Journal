-- verify-dish-index-step-11.sql — Run after fix-dish-index-import-excel.sql (+ optional repair)
-- Quick PASS checks for import mapping and archived test row.

-- 1) Import mapper includes Visibility
SELECT 'import_visibility_mapped' AS check_name,
       CASE WHEN pg_get_functiondef(p.oid) LIKE '%Visibility%'
            AND pg_get_functiondef(p.oid) LIKE '%visibility%'
            THEN 'PASS' ELSE 'FAIL' END AS status
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'rnl_csv_row_to_jsonb';

-- 2) Division placeholder + Not set difficulty in mapper
SELECT 'import_division_none' AS check_name,
       CASE WHEN pg_get_functiondef(p.oid) LIKE '%(none)%' THEN 'PASS' ELSE 'FAIL' END AS status
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'rnl_csv_row_to_jsonb';

SELECT 'import_difficulty_not_set' AS check_name,
       CASE WHEN pg_get_functiondef(p.oid) LIKE '%Not set%' THEN 'PASS' ELSE 'FAIL' END AS status
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.proname = 'rnl_csv_row_to_jsonb';

-- 3) Archived test row (run repair SQL first if FAIL)
SELECT 'archived_test_row' AS check_name,
       dish_code,
       is_active,
       content_status,
       division,
       CASE WHEN dish_code = 'DI900008'
                 AND is_active = false
                 AND content_status = 'retired'
            THEN 'PASS' ELSE 'FAIL' END AS status
  FROM public.recipe_name_library
 WHERE dish_code IN ('DI900008', 'DI900009')
   AND notes LIKE '%[TCJ_TEST_SEED]%'
 ORDER BY dish_code;
