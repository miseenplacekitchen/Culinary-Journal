-- Recipe batch upload — allow service_role to insert pending recipes
-- Run once in Supabase SQL Editor when run_books.bat shows:
--   permission denied for table submitted_recipes (42501)
--
-- Safe to re-run.

GRANT USAGE ON SCHEMA public TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.submitted_recipes TO service_role;
-- Groq polish script (run_polish_books.bat) matches ingredient names against this table
GRANT SELECT ON public.ingredients TO service_role;

SELECT 'fix-recipe-batch-ingest.sql complete' AS status;
