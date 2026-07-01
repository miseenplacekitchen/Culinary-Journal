-- verify-dish-index-test-data.sql — Run after seed-dish-index-test-data.sql
-- Reports PASS/FAIL checks you can paste back to Cursor. No admin session required.

WITH seed AS (
  SELECT * FROM public.recipe_name_library WHERE notes LIKE '%[TCJ_TEST_SEED]%'
),
checks AS (
  SELECT 1 AS ord, 'seed_row_count >= 10' AS check_name,
         (SELECT count(*)::int FROM seed) >= 10 AS ok,
         (SELECT count(*)::text FROM seed) AS detail
  UNION ALL
  SELECT 2, 'duplicate_cluster_dosa >= 2',
         (SELECT count(*)::int FROM seed WHERE public.rnl_normalize_name(recipe_name) = 'dosa') >= 2,
         (SELECT count(*)::text FROM seed WHERE public.rnl_normalize_name(recipe_name) = 'dosa')
  UNION ALL
  SELECT 3, 'duplicate_cluster_idli >= 2',
         (SELECT count(*)::int FROM seed WHERE public.rnl_normalize_name(recipe_name) = 'idli') >= 2,
         (SELECT count(*)::text FROM seed WHERE public.rnl_normalize_name(recipe_name) = 'idli')
  UNION ALL
  SELECT 4, 'missing_category >= 2',
         (SELECT count(*)::int FROM seed WHERE COALESCE(is_active,true) AND btrim(COALESCE(category,'')) = '') >= 2,
         (SELECT count(*)::text FROM seed WHERE btrim(COALESCE(category,'')) = '')
  UNION ALL
  SELECT 5, 'missing_country >= 1',
         (SELECT count(*)::int FROM seed WHERE COALESCE(is_active,true) AND btrim(COALESCE(origin_country,'')) = '') >= 1,
         (SELECT count(*)::text FROM seed WHERE btrim(COALESCE(origin_country,'')) = '')
  UNION ALL
  SELECT 6, 'archived_seed >= 1',
         (SELECT count(*)::int FROM seed WHERE is_active = false) >= 1,
         (SELECT count(*)::text FROM seed WHERE is_active = false)
  UNION ALL
  SELECT 7, 'ready_to_draft_unlinked >= 1',
         (SELECT count(*)::int FROM seed WHERE research_status = 'ready_to_draft' AND linked_recipe_id IS NULL) >= 1,
         (SELECT count(*)::text FROM seed WHERE research_status = 'ready_to_draft')
  UNION ALL
  SELECT 8, 'needs_research >= 2',
         (SELECT count(*)::int FROM seed WHERE research_status = 'needs_research') >= 2,
         (SELECT count(*)::text FROM seed WHERE research_status = 'needs_research')
  UNION ALL
  SELECT 9, 'rpc_duplicate_clusters_exists',
         EXISTS (
           SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = 'admin_dish_index_duplicate_clusters'
         ),
         'fn'
  UNION ALL
  SELECT 10, 'rpc_coverage_gaps_exists',
         EXISTS (
           SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = 'admin_dish_index_coverage_gaps'
         ),
         'fn'
  UNION ALL
  SELECT 11, 'rpc_queue_counts_exists',
         EXISTS (
           SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = 'admin_dish_index_queue_counts'
         ),
         'fn'
  UNION ALL
  SELECT 12, 'normalize_helper_exists',
         EXISTS (
           SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = 'rnl_normalize_name'
         ),
         'fn'
)
SELECT
  CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status,
  check_name,
  detail
FROM checks
ORDER BY ord;

-- Expected duplicate groups (informational)
SELECT 'duplicate_groups' AS report,
       public.rnl_normalize_name(recipe_name) AS norm_name,
       count(*)::int AS cnt,
       array_agg(dish_code ORDER BY dish_code) AS codes
  FROM public.recipe_name_library
 WHERE COALESCE(is_active, true) = true
   AND btrim(COALESCE(recipe_name, '')) <> ''
 GROUP BY 1, 2
HAVING count(*) > 1
 ORDER BY cnt DESC, norm_name;
