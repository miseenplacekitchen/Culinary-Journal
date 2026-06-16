-- fix-clean-non-lebanese-book-recipes.sql
-- Remove all book-batch imports except Lebanese Home Cooking (one-book deep dive).
-- Run in Supabase SQL Editor. Review the preview counts first, then run the DELETE.

-- Preview what will be removed
SELECT
  CASE
    WHEN import_source_url LIKE 'tcj://books/Lebanese Home Cooking - Kamal Mouzawak%'
      THEN 'KEEP — Lebanese'
    WHEN import_source_url LIKE 'tcj://books/%'
      THEN 'DELETE — ' || split_part(replace(import_source_url, 'tcj://books/', ''), '#', 1)
    ELSE 'DELETE — other book-batch'
  END AS action,
  status,
  count(*)::int AS recipes
FROM public.submitted_recipes
WHERE import_path = 'book-batch'
   OR import_source_url LIKE 'tcj://books/%'
GROUP BY 1, 2
ORDER BY 1, 2;

-- Remove every book import except Lebanese Home Cooking
DELETE FROM public.submitted_recipes
WHERE (import_path = 'book-batch' OR import_source_url LIKE 'tcj://books/%')
  AND COALESCE(import_source_url, '') NOT LIKE 'tcj://books/Lebanese Home Cooking - Kamal Mouzawak%';

-- Optional: wipe Lebanese too for a completely fresh re-upload after run_books.bat
-- DELETE FROM public.submitted_recipes
-- WHERE import_source_url LIKE 'tcj://books/Lebanese Home Cooking - Kamal Mouzawak%';

-- Verify
SELECT status, count(*)::int AS recipes
FROM public.submitted_recipes
WHERE import_source_url LIKE 'tcj://books/%'
   OR import_path = 'book-batch'
GROUP BY status
ORDER BY status;
