-- ══════════════════════════════════════════════════════════════════════
-- sync-submitted-recipes-columns.sql
-- Adds all columns that submit-recipe.html sends but 01-schema.sql
-- does not yet define. Safe to re-run — all ADD COLUMN IF NOT EXISTS.
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS additional_time_minutes integer;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS servings_unit            text DEFAULT 'people';
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS shelf_life_value         text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS shelf_life_unit          text DEFAULT 'months';
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS shelf_life_storage       text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS after_open_value         text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS after_open_unit          text DEFAULT 'weeks';
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS reviewer_id              uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS unknown_ingredients      text[];
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS unknown_utensils        text[];
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS taxonomy_suggestions     jsonb DEFAULT '[]'::jsonb;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS cooking_style            text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS origin_locality          text;

-- Also ensure reviewer_notes exists (used by admin_review_recipe)
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS reviewer_notes           text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS reviewed_at              timestamptz;

-- Wave 3 import audit (see fix-phase38-import-audit.sql)
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS paste_text              text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS source_url              text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS parser_version          text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS extractor_version       text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS import_extractor        text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS import_confidence_score integer;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS import_warnings         jsonb DEFAULT '[]'::jsonb;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS import_paste_snapshot   text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS import_raw_article_text text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS imported_at             timestamptz;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS procedure_rewritten     boolean DEFAULT false;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS import_merge_mode       boolean DEFAULT false;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS import_source_url       text;

SELECT 'submitted_recipes columns synced' AS status;
