-- ══════════════════════════════════════════════════════════════════════
-- fix-phase38-import-audit.sql — Wave 3 import audit trail (section U)
-- Safe to re-run. Run in Supabase SQL Editor after sync-submitted-recipes-columns.sql
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS paste_text              text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS source_url              text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS parser_version          text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS extractor_version       text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_extractor        text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_confidence_score integer;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_warnings         jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_paste_snapshot   text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_raw_article_text text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS imported_at             timestamptz;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS procedure_rewritten     boolean DEFAULT false;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_merge_mode       boolean DEFAULT false;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_source_url       text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_path             text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_attribution_notice text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_page_title       text;

COMMENT ON COLUMN public.submitted_recipes.import_paste_snapshot IS 'Structured paste text immediately after extract/parse pipeline';
COMMENT ON COLUMN public.submitted_recipes.import_raw_article_text IS 'Truncated raw article text from URL fetch (first ~8000 chars)';
COMMENT ON COLUMN public.submitted_recipes.import_warnings IS 'Parser warnings array from confidence gate';

SELECT 'Phase 38 import audit columns ready' AS status;
