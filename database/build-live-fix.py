#!/usr/bin/env python3
"""Build database/sql/fix-all-live.sql from canonical one-shot sections."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "sql" / "fix-all-live.sql"

HEADER = """-- ══════════════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — fix-all-live.sql
-- One script for Supabase SQL Editor. Safe to re-run.
--
-- What it does:
--   • Adds missing columns (IF NOT EXISTS only — no data loss)
--   • Removes stale duplicate function signatures
--   • Replaces broken/missing RPCs with canonical versions
--
-- What it does NOT do:
--   • Drop tables, truncate data, or run 00-drop-functions.sql
-- ══════════════════════════════════════════════════════════════════════

"""

SIGNATURE_CLEANUP = """
-- ── 1. Remove stale duplicate signatures ─────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipes(text);
DROP FUNCTION IF EXISTS public.admin_bulk_update_field(uuid[], text, text);

DO $$ DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('admin_deactivate_user', 'admin_bulk_update_field', 'admin_get_recipes')
      AND pg_get_function_identity_arguments(p.oid) NOT IN (
        'p_user_id uuid, p_type text, p_days integer, p_reason text',
        'p_ids integer[], p_field text, p_value text',
        'p_status text, p_search text, p_category text, p_limit integer, p_offset integer'
      )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig;
  END LOOP;
END $$;

-- ── 2. Safe column additions ───────────────────────────────────────
ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS is_featured            BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS featured_at            TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_recipe_of_week      BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recipe_of_week_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS recipe_of_week_expires TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS native_title           TEXT,
  ADD COLUMN IF NOT EXISTS introduction           TEXT,
  ADD COLUMN IF NOT EXISTS cooking_notes          TEXT,
  ADD COLUMN IF NOT EXISTS photo_url              TEXT;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='deactivation_type') THEN
    ALTER TABLE public.profiles ADD COLUMN deactivation_type text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='deactivation_expires_at') THEN
    ALTER TABLE public.profiles ADD COLUMN deactivation_expires_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='deactivation_reason') THEN
    ALTER TABLE public.profiles ADD COLUMN deactivation_reason text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='avatar_url') THEN
    ALTER TABLE public.profiles ADD COLUMN avatar_url text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='ingredients' AND column_name='extra_fields') THEN
    ALTER TABLE public.ingredients ADD COLUMN extra_fields jsonb DEFAULT '{}'::jsonb;
  END IF;
END $$;

"""

FOOTER = """
-- ── Reload PostgREST schema cache ──────────────────────────────────
SELECT pg_notify('pgrst', 'reload schema');

SELECT 'fix-all-live.sql complete' AS status;
"""

SECTION_FILES = [
    ("Profile RPCs", "fix-profile-avatar.sql"),
    ("Recipe admin RPCs", "fix-admin-recipes.sql"),
    ("Ingredient sort RPC", "fix-admin-ingredient-sort.sql"),
    ("CSV import RPC", "fix-admin-bulk-import.sql"),
    ("CJ-006 recipe pipeline", "fix-cj006-pipeline.sql"),
    ("Phase 2 batch", "fix-phase2-batch.sql"),
    ("PF-02 / PF-08 pantry", "fix-pf02-pf08.sql"),
    ("Family baby food stage", "fix-family-food-stage.sql"),
]

# Inline snippets not worth separate files — write helper files first
IS_ADMIN = """
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_admin = true
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
"""

ADMIN_CORE = """
CREATE OR REPLACE FUNCTION public.admin_get_stats()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'pending',  COUNT(*) FILTER (WHERE status = 'pending'),
    'approved', COUNT(*) FILTER (WHERE status = 'approved'),
    'rejected', COUNT(*) FILTER (WHERE status = 'rejected'),
    'featured', COUNT(*) FILTER (WHERE is_featured = true),
    'total',    COUNT(*)
  ) INTO result FROM public.submitted_recipes;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_stats() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id uuid, p_status text, p_notes text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_name    text;
  v_msg     text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;
  SELECT user_id, recipe_name INTO v_user_id, v_name
    FROM public.submitted_recipes WHERE id = p_id;
  UPDATE public.submitted_recipes
     SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
   WHERE id = p_id;
  IF v_user_id IS NOT NULL AND p_status IN ('approved', 'rejected') THEN
    v_msg := CASE p_status
      WHEN 'approved' THEN 'Your recipe "' || COALESCE(v_name, 'submission') || '" was approved and is now live!'
      ELSE 'Your recipe "' || COALESCE(v_name, 'submission') || '" needs updates.'
           || CASE WHEN COALESCE(p_notes, '') <> '' THEN ' ' || p_notes ELSE '' END
    END;
    INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
    VALUES (
      v_user_id,
      CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
      p_id, v_name, v_msg
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_bulk_update_field(
  p_ids int[], p_field text, p_value text
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  allowed text[] := ARRAY['Category','Sub Category','Vegan (Yes/No)','Vegetarian (Yes/No)',
                          'Allergen','Liquid (Yes/No)','CJ Recommended Brand','Unit','Notes'];
  affected int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NOT (p_field = ANY(allowed)) THEN RAISE EXCEPTION 'Field not allowed: %', p_field; END IF;
  EXECUTE format('UPDATE public.ingredients SET %I = $1 WHERE "ID" = ANY($2)', p_field)
    USING p_value, p_ids;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_bulk_update_field(int[], text, text) TO authenticated;
"""

DEACTIVATE = """
CREATE OR REPLACE FUNCTION public.deactivate_my_account()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.profiles SET is_active = false WHERE id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.deactivate_my_account() TO authenticated;

DROP FUNCTION IF EXISTS public.admin_deactivate_user(uuid, text, integer, text);
CREATE OR REPLACE FUNCTION public.admin_deactivate_user(
  p_user_id uuid, p_type text, p_days int DEFAULT NULL, p_reason text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active               = false,
    deactivation_type       = p_type,
    deactivation_expires_at = CASE
      WHEN p_type = 'temporary' AND p_days IS NOT NULL
      THEN now() + (p_days || ' days')::interval ELSE NULL END,
    deactivation_reason     = p_reason
  WHERE id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_user(uuid, text, integer, text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_reactivate_user(uuid);
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active = true, deactivation_type = NULL,
    deactivation_expires_at = NULL, deactivation_reason = NULL
  WHERE id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_user(uuid) TO authenticated;
"""

USER_DELETE = """
-- Diary + culinary life delete (returns json so the UI can confirm success)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.diary_entries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cooking_events TO authenticated;

DROP POLICY IF EXISTS "Users manage own diary" ON public.diary_entries;
CREATE POLICY "Users manage own diary"
  ON public.diary_entries FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own cooking events" ON public.cooking_events;
CREATE POLICY "Users manage own cooking events"
  ON public.cooking_events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DO $$ DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('delete_diary_entry', 'delete_cooking_event')
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.delete_diary_entry(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN RAISE EXCEPTION 'missing_id'; END IF;
  DELETE FROM public.diary_entries WHERE id = p_id AND user_id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN RAISE EXCEPTION 'diary_entry_not_found'; END IF;
  RETURN jsonb_build_object('deleted', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.delete_diary_entry(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_diary_entry(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_cooking_event(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN RAISE EXCEPTION 'missing_id'; END IF;
  DELETE FROM public.cooking_events WHERE id = p_id AND user_id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN RAISE EXCEPTION 'cooking_event_not_found'; END IF;
  RETURN jsonb_build_object('deleted', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.delete_cooking_event(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_cooking_event(uuid) TO authenticated;
"""


def strip_fix_preamble(text: str) -> str:
    """Drop comments and trailing pg_notify from individual fix files."""
    lines = text.splitlines()
    out = []
    for line in lines:
        if line.strip().startswith('--'):
            continue
        if 'pg_notify' in line:
            continue
        if line.strip().startswith('SELECT pg_notify'):
            continue
        out.append(line)
    return '\n'.join(out).strip() + '\n'


def main():
    parts = [HEADER, SIGNATURE_CLEANUP, IS_ADMIN.strip() + '\n']

    for label, filename in SECTION_FILES:
        path = ROOT / "sql" / filename
        if not path.exists():
            raise SystemExit(f'Missing section file: {path}')
        body = strip_fix_preamble(path.read_text(encoding='utf-8'))
        parts.append(f'\n-- ── {label} ──\n')
        parts.append(body)

    for label, body in [
        ("Admin stats, review & bulk field", ADMIN_CORE),
        ("User deactivation", DEACTIVATE),
        ("Diary & culinary delete", USER_DELETE),
    ]:
        parts.append(f'\n-- ── {label} ──\n')
        parts.append(body.strip() + '\n')

    parts.append(FOOTER)
    OUT.write_text(''.join(parts), encoding='utf-8')
    print(f'Wrote {OUT} ({OUT.stat().st_size:,} bytes)')


if __name__ == '__main__':
    main()
