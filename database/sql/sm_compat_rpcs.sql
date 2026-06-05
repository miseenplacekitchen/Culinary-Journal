-- ══════════════════════════════════════════════════════════════════════
-- Site Management compatibility RPCs
-- Must run AFTER base site management tables exist
-- ══════════════════════════════════════════════════════════════════════

-- ── Guard: only run if base tables exist ─────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_name = 'site_announcements' AND table_schema = 'public'
  ) THEN
    RAISE EXCEPTION 'site_announcements table does not exist. Run sm_rpc_functions.sql or MASTER-SETUP.sql first.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_name = 'site_pages' AND table_schema = 'public'
  ) THEN
    RAISE EXCEPTION 'site_pages table does not exist. Run site management setup first.';
  END IF;
END; $$;

-- ── Column guards ─────────────────────────────────────────────────────
ALTER TABLE site_announcements ADD COLUMN IF NOT EXISTS expires_at   timestamptz;
ALTER TABLE site_pages         ADD COLUMN IF NOT EXISTS meta_title   text;
ALTER TABLE site_pages         ADD COLUMN IF NOT EXISTS meta_desc    text;
ALTER TABLE site_pages         ADD COLUMN IF NOT EXISTS updated_at   timestamptz DEFAULT NOW();
ALTER TABLE site_pages         ADD COLUMN IF NOT EXISTS coming_soon  boolean     DEFAULT false;

-- Add unique constraint on path if missing (required for ON CONFLICT)
DO $$ BEGIN
  -- Detect duplicate paths and raise error rather than silently delete data
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'site_pages' AND table_schema = 'public'
  ) THEN
    IF EXISTS (
      SELECT path FROM site_pages GROUP BY path HAVING COUNT(*) > 1
    ) THEN
      RAISE EXCEPTION 'site_pages has duplicate path values. Resolve duplicates manually before running this migration.';
    END IF;
  END IF;
  -- Add unique constraint if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_schema = 'public'
      AND table_name   = 'site_pages'
      AND column_name  = 'path'
      AND constraint_name IN (
        SELECT constraint_name FROM information_schema.table_constraints
        WHERE table_schema = 'public' AND table_name = 'site_pages'
          AND constraint_type = 'UNIQUE'
      )
  ) THEN
    ALTER TABLE site_pages ADD CONSTRAINT site_pages_path_unique UNIQUE (path);
  END IF;
END; $$;

-- Do NOT drop NOT NULL on name — function supplies fallback so it is not needed
-- site_pages.name stays NOT NULL

-- ── admin_save_announcement ───────────────────────────────────────────
-- p_active uses NULL default so COALESCE(p_active, active) works correctly
-- p_id = 0 → insert new; p_id > 0 → update existing (errors if not found)
DROP FUNCTION IF EXISTS admin_save_announcement(int, text, text, boolean, timestamptz);
CREATE FUNCTION admin_save_announcement(
  p_id         int          DEFAULT 0,
  p_text       text         DEFAULT NULL,
  p_type       text         DEFAULT NULL,
  p_active     boolean      DEFAULT NULL,
  p_expires_at timestamptz  DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF p_id > 0 THEN
    UPDATE site_announcements SET
      text       = COALESCE(p_text,   text),
      type       = COALESCE(p_type,   type),
      active     = COALESCE(p_active, active),
      expires_at = COALESCE(p_expires_at, expires_at)
    WHERE id = p_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RAISE EXCEPTION 'Announcement with id % not found', p_id;
    END IF;
  ELSE
    INSERT INTO site_announcements (text, type, active, expires_at)
    VALUES (p_text, COALESCE(p_type, 'info'), COALESCE(p_active, true), p_expires_at)
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object('id', v_id);
END; $$;
REVOKE ALL ON FUNCTION admin_save_announcement(int, text, text, boolean, timestamptz) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION admin_save_announcement(int, text, text, boolean, timestamptz) TO authenticated;

-- ── admin_update_site_page ────────────────────────────────────────────
-- Validates p_path before inserting; uses name fallback; unique constraint required
DROP FUNCTION IF EXISTS admin_update_site_page(text, text, text, text, boolean);
DROP FUNCTION IF EXISTS admin_update_site_page(text, text, text, text);
CREATE FUNCTION admin_update_site_page(
  p_path       text DEFAULT NULL,
  p_visibility text DEFAULT NULL,
  p_meta_title text DEFAULT NULL,
  p_meta_desc  text DEFAULT NULL,
  p_coming_soon boolean DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  IF p_path IS NULL OR TRIM(p_path) = '' THEN
    RAISE EXCEPTION 'p_path must not be null or empty';
  END IF;

  INSERT INTO site_pages (path, name, visibility, meta_title, meta_desc, coming_soon, updated_at)
  VALUES (
    TRIM(p_path),
    TRIM(p_path),
    COALESCE(p_visibility, 'public'),
    p_meta_title,
    p_meta_desc,
    COALESCE(p_coming_soon, false),
    NOW()
  )
  ON CONFLICT (path) DO UPDATE SET
    visibility = CASE WHEN p_visibility IS NOT NULL THEN p_visibility ELSE site_pages.visibility END,
    meta_title = COALESCE(EXCLUDED.meta_title, site_pages.meta_title),
    meta_desc    = COALESCE(EXCLUDED.meta_desc,  site_pages.meta_desc),
    coming_soon  = CASE WHEN p_coming_soon IS NOT NULL THEN p_coming_soon ELSE site_pages.coming_soon END,
    updated_at   = NOW();
END; $$;
REVOKE ALL ON FUNCTION admin_update_site_page(text, text, text, text, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION admin_update_site_page(text, text, text, text, boolean) TO authenticated;

SELECT 'Site management compat RPCs ready' AS status;

-- ── search_ingredients(p_query, p_limit) ─────────────────────────────
-- Safe ingredient search — avoids spaced column names in REST filters
DROP FUNCTION IF EXISTS search_ingredients(text, int);
CREATE FUNCTION search_ingredients(
  p_query text DEFAULT '',
  p_limit int  DEFAULT 12
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN COALESCE(
    (SELECT jsonb_agg(r)
     FROM (
       SELECT
         "ID"                                 AS id,
         "Ingredient Name"                    AS ingredient_name,
         "Also Known As"                      AS also_known_as,
         "Category"                           AS category,
         "Allergen"                           AS allergen,
         "Vegan (Yes/No)"                     AS vegan
       FROM ingredients
       WHERE p_query = ''
          OR "Ingredient Name" ILIKE '%' || p_query || '%'
          OR "Also Known As"   ILIKE '%' || p_query || '%'
       ORDER BY "Ingredient Name" ASC
       LIMIT p_limit
     ) r),
    '[]'::jsonb
  );
END; $$;
REVOKE ALL ON FUNCTION search_ingredients(text, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION search_ingredients(text, int) TO anon, authenticated;
