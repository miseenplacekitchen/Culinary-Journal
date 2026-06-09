# Supabase SQL run order (import stack)

Run in the Supabase SQL Editor when setting up or upgrading import audit:

1. `database/sql/01-schema.sql` (base tables)
2. `database/sql/sync-submitted-recipes-columns.sql` (if present — column sync)
3. `database/sql/fix-phase36-platform-batch.sql` (`cleanup_recipe_ocr` RPC)
4. `database/sql/fix-phase38-import-audit.sql` (import audit columns)
5. `database/sql/recipe_management.sql` (`recipe_drafts` table)

Re-run `fix-phase38-import-audit.sql` safely — it uses `ADD COLUMN IF NOT EXISTS`.
