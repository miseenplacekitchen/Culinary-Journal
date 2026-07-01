-- verify-dish-index-queue-counts.sql — Explain queue pill numbers vs table rows (read-only)
-- Run anytime in Supabase SQL Editor. No changes made.

WITH base AS (
  SELECT rnl.dish_code,
         rnl.recipe_name,
         rnl.research_status,
         COALESCE(rnl.is_active, true) AS is_active,
         rnl.linked_recipe_id,
         CASE
           WHEN COALESCE(rnl.is_active, true) = false THEN 'archived'
           WHEN rnl.research_status = 'idea_only' THEN 'idea_only'
           WHEN rnl.research_status = 'needs_research' THEN 'needs_research'
           WHEN rnl.linked_recipe_id IS NOT NULL
                AND sr.id IS NOT NULL
                AND public.rnl_has_drift(rnl, sr) THEN 'linked_drift'
           WHEN rnl.research_status = 'ready_to_draft'
                AND rnl.linked_recipe_id IS NULL THEN 'ready_unlinked'
           WHEN rnl.research_status = 'ready_to_draft' THEN 'ready_linked'
           WHEN rnl.research_status = 'verified'
                AND rnl.linked_recipe_id IS NULL THEN 'verified_unlinked'
           WHEN rnl.research_status = 'verified' THEN 'verified_linked'
           ELSE 'other'
         END AS queue_bucket
    FROM public.recipe_name_library rnl
    LEFT JOIN public.submitted_recipes sr ON sr.id = rnl.linked_recipe_id
)
SELECT queue_bucket, count(*)::int AS n
  FROM base
 GROUP BY queue_bucket
 ORDER BY CASE queue_bucket
   WHEN 'idea_only' THEN 1
   WHEN 'needs_research' THEN 2
   WHEN 'ready_unlinked' THEN 3
   WHEN 'ready_linked' THEN 4
   WHEN 'verified_unlinked' THEN 5
   WHEN 'verified_linked' THEN 6
   WHEN 'linked_drift' THEN 7
   WHEN 'other' THEN 8
   WHEN 'archived' THEN 9
   ELSE 10
 END;

SELECT 'active_rows' AS report, count(*)::int AS n
  FROM public.recipe_name_library WHERE COALESCE(is_active, true);

SELECT 'archived_rows' AS report, count(*)::int AS n
  FROM public.recipe_name_library WHERE COALESCE(is_active, true) = false;

SELECT dish_code, recipe_name, research_status, queue_bucket
  FROM (
    SELECT rnl.dish_code, rnl.recipe_name, rnl.research_status,
           CASE WHEN COALESCE(rnl.is_active, true) = false THEN 'archived' ELSE 'active' END AS queue_bucket
      FROM public.recipe_name_library rnl
  ) t
 ORDER BY queue_bucket, dish_code;
