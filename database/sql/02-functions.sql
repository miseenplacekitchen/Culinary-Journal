-- ══════════════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 02-functions.sql
-- ══════════════════════════════════════════════════════════════════════
-- ⚠️  MIGRATION ORDER REQUIRED — DO NOT run this file in isolation.
--
-- This file drops and recreates core functions by name. Running it
-- out of order on a live database can break login, profiles, recipes,
-- notifications, and collections.
--
-- REQUIRED RUN ORDER:
--   1. 00-drop-functions.sql   (clears stale signatures)
--   2. 01-schema.sql           (tables, indexes, RLS)
--   3. 02-functions.sql        ← this file
--   4. table_planner.sql       (MUST run after — overwrites any TP
--                               functions that 02 may still define)
--   5. Remaining files in CANONICAL_MIGRATION_ORDER.md
--
-- If you only need to restore a single function, use a targeted
-- CREATE OR REPLACE FUNCTION statement directly in SQL Editor.
-- ══════════════════════════════════════════════════════════════════════

-- NOTE: the seven admin ingredient functions (admin_get_ingredients,
-- admin_upsert_ingredient, admin_delete_ingredient, admin_count_ingredients,
-- admin_export_ingredients, admin_get_ingredient_units,
-- admin_bulk_upsert_ingredients) live in admin_rpcs.sql — their single
-- home file. They were removed from here to end the dual-definition
-- conflict (one function, one file).

-- ── ADMIN HELPER ─────────────────────────────────────────────────
-- Must exist first — all other admin functions depend on it.
-- is_admin() must never be dropped — RLS policies depend on it.
-- CREATE OR REPLACE is safe here; no DROP needed.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND is_admin = true
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── AUTH / PROFILE ────────────────────────────────────────────────

-- Used by login page to look up user by email or username
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_login_info' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_login_info(identifier text)
RETURNS TABLE (
  email          text,
  username       text,
  is_active      boolean,
  is_admin       boolean,
  account_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Reads canonical email from auth.users so this works
  -- even if profiles.email is missing or stale.
  RETURN QUERY
    SELECT
      u.email::text,
      p.username,
      p.is_active,
      p.is_admin,
      CASE WHEN p.is_active = false THEN 'deactivated' ELSE 'active' END::text
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE LOWER(u.email)    = LOWER(identifier)
       OR LOWER(p.username) = LOWER(identifier)
    LIMIT 1;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_login_info(text) TO anon, authenticated;

-- Get current user's full profile — includes all preference fields
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id                  uuid,
  full_name           text,
  username            text,
  email               text,
  is_active           boolean,
  is_admin            boolean,
  theme_preference    text,
  dietary_preferences text[],
  allergies           text[],
  health_conditions   text[],
  cooking_style       text,
  font_size           text,
  avatar_url          text,
  created_at          timestamptz,
  last_seen           timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT p.id,
           p.full_name::text,
           p.username::text,
           u.email::text,
           p.is_active,
           p.is_admin,
           p.theme_preference::text,
           COALESCE(p.dietary_preferences, '{}')::text[],
           COALESCE(p.allergies, '{}')::text[],
           COALESCE(p.health_conditions, '{}')::text[],
           COALESCE(p.cooking_style, '')::text,
           COALESCE(p.font_size, 'medium')::text,
           p.avatar_url::text,
           u.created_at,
           p.last_seen
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

-- Update name and/or username
CREATE OR REPLACE FUNCTION public.update_my_profile(
  new_full_name text,
  new_username  text
)
RETURNS TABLE (
  id uuid, full_name text, username text, email text,
  is_active boolean, theme_preference text, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF new_username IS NOT NULL THEN
    IF length(new_username) < 3 OR length(new_username) > 20
      THEN RAISE EXCEPTION 'username_invalid_length'; END IF;
    IF new_username !~ '^[A-Za-z0-9_-]+$'
      THEN RAISE EXCEPTION 'username_invalid_chars'; END IF;
    IF EXISTS (SELECT 1 FROM public.profiles
               WHERE LOWER(username) = LOWER(new_username) AND id <> auth.uid())
      THEN RAISE EXCEPTION 'username_taken'; END IF;
  END IF;
  IF new_full_name IS NOT NULL AND length(trim(new_full_name)) = 0
    THEN RAISE EXCEPTION 'name_empty'; END IF;
  UPDATE public.profiles
     SET full_name = COALESCE(new_full_name, full_name),
         username  = COALESCE(new_username,  username)
   WHERE id = auth.uid();
  RETURN QUERY
    SELECT p.id,
           p.full_name::text,
           p.username::text,
           u.email::text,
           p.is_active,
           p.theme_preference::text,
           u.created_at
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_my_profile(text,text) TO authenticated;

-- Update theme only
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'update_my_theme' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.update_my_theme(new_theme text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF new_theme IS NULL OR length(new_theme) = 0 THEN RAISE EXCEPTION 'theme_required'; END IF;
  UPDATE public.profiles SET theme_preference = new_theme WHERE id = auth.uid();
  RETURN new_theme;
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_my_theme(text) TO authenticated;

-- Update all user preferences (dietary, allergies, health, style, font)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'update_my_preferences' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.update_my_preferences(
  p_dietary_preferences text[],
  p_allergies           text[],
  p_health_conditions   text[],
  p_cooking_style       text,
  p_font_size           text DEFAULT 'medium'
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.profiles SET
    dietary_preferences = COALESCE(p_dietary_preferences, '{}'),
    allergies           = COALESCE(p_allergies,           '{}'),
    health_conditions   = COALESCE(p_health_conditions,   '{}'),
    cooking_style       = COALESCE(p_cooking_style,       ''),
    font_size           = COALESCE(p_font_size,           'medium')
  WHERE id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_my_preferences(text[],text[],text[],text,text) TO authenticated;

-- Deactivate own account
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'deactivate_my_account' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
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

-- Public user profile (no auth required)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_public_profile' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_public_profile(p_username text)
RETURNS TABLE (
  id               uuid,
  username         text,
  full_name        text,
  created_at       timestamptz,
  recipe_count     bigint,
  collection_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT p.id, p.username, p.full_name, u.created_at,
      (SELECT COUNT(*) FROM public.submitted_recipes sr
       WHERE sr.user_id = p.id AND sr.status = 'approved'
         AND sr.visibility = 'Public')::bigint,
      (SELECT COUNT(*) FROM public.collections c
       WHERE c.user_id = p.id AND c.is_public = true)::bigint
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE LOWER(p.username) = LOWER(p_username)
      AND COALESCE(p.is_active, true) = true;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_public_profile(text) TO anon, authenticated;

-- ── RECIPES ──────────────────────────────────────────────────────

-- Get current user's own submissions
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_my_submissions' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_my_submissions()
RETURNS TABLE (
  id             uuid,
  recipe_name    text,
  category       text,
  status         text,
  visibility     text,
  submitted_at   timestamptz,
  reviewed_at    timestamptz,
  reviewer_notes text,
  image_url      text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT sr.id, sr.recipe_name, sr.category, sr.status, sr.visibility,
           sr.submitted_at, sr.reviewed_at, sr.reviewer_notes, sr.image_url
    FROM public.submitted_recipes sr
    WHERE sr.user_id = auth.uid()
    ORDER BY sr.submitted_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_submissions() TO authenticated;

-- Get approved public recipes (listing page, community section)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_approved_recipes' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_approved_recipes(
  p_category text DEFAULT NULL,
  p_spice    text DEFAULT NULL,
  p_dietary  text DEFAULT NULL,
  p_search   text DEFAULT NULL,
  p_limit    int  DEFAULT 50,
  p_offset   int  DEFAULT 0
)
RETURNS TABLE (
  id             uuid,
  recipe_name    text,
  native_title   text,
  category       text,
  spice_level    text,
  dietary_tags   text[],
  origin_country text,
  image_url      text,
  credit_name    text,
  credit_handle  text,
  submitted_at   timestamptz,
  username       text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT sr.id, sr.recipe_name, sr.native_title, sr.category,
           sr.spice_level, sr.dietary_tags, sr.origin_country,
           sr.image_url, sr.credit_name, sr.credit_handle,
           sr.submitted_at, p.username
    FROM public.submitted_recipes sr
    LEFT JOIN public.profiles p ON p.id = sr.user_id
    WHERE sr.status     = 'approved'
      AND sr.visibility = 'Public'
      AND (p_category IS NULL OR sr.category = p_category)
      AND (p_spice    IS NULL OR sr.spice_level = p_spice)
      AND (p_dietary  IS NULL OR p_dietary = ANY(sr.dietary_tags))
      AND (p_search   IS NULL OR sr.recipe_name ILIKE '%'||p_search||'%')
    ORDER BY sr.submitted_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_approved_recipes(text,text,text,text,int,int) TO anon, authenticated;

-- Public recipe page fetch — includes submitter username; enforces visibility server-side
DROP FUNCTION IF EXISTS public.get_public_recipe(uuid);
CREATE OR REPLACE FUNCTION public.get_public_recipe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row   public.submitted_recipes%ROWTYPE;
  v_user  text;
  v_uid   uuid;
BEGIN
  IF p_id IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO v_row
    FROM public.submitted_recipes
   WHERE id = p_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT username INTO v_user
    FROM public.profiles
   WHERE id = v_row.user_id;
  v_uid := auth.uid();
  IF is_admin()
     OR (v_uid IS NOT NULL AND v_row.user_id = v_uid)
     OR (v_row.status = 'approved' AND v_row.visibility = 'Public')
  THEN
    RETURN to_jsonb(v_row) || jsonb_build_object('username', v_user);
  END IF;
  RETURN NULL;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_public_recipe(uuid) TO anon, authenticated;

-- Quick edit: name, visibility, description only
-- FIX: stores correct case — 'Public'/'Private'/'Archived' not lowercased
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'quick_update_recipe' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.quick_update_recipe(
  p_id          uuid,
  p_name        text,
  p_visibility  text,
  p_description text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.submitted_recipes SET
    recipe_name = p_name,
    visibility  = p_visibility,
    description = COALESCE(p_description, description)
  WHERE id = p_id AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.quick_update_recipe(uuid,text,text,text) TO authenticated;

-- ── ADMIN — RECIPES ──────────────────────────────────────────────

-- admin_get_recipes — MOVED to recipe_management.sql (its home file) on 5 Jun 2026.
-- The old 1-parameter version here did not match the dashboard JS call
-- signature (p_status, p_search, p_category, p_limit, p_offset) and broke
-- the entire Recipe Management panel. Do not redefine it in this file.

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'admin_get_stats' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
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

-- admin_review_recipe — MOVED to recipe_management.sql (canonical owner per manifest.json).
-- Do not redefine here; fresh installs get it from recipe_management.sql in setup_order.

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'admin_get_submitter' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.admin_get_submitter(p_user_id uuid)
RETURNS text
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$
  SELECT email FROM auth.users WHERE id = p_user_id AND is_admin();
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_submitter(uuid) TO authenticated;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'admin_get_analytics' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.admin_get_analytics()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'total_users',      (SELECT COUNT(*) FROM public.profiles),
    'total_recipes',    (SELECT COUNT(*) FROM public.submitted_recipes),
    'pending_recipes',  (SELECT COUNT(*) FROM public.submitted_recipes WHERE status='pending'),
    'approved_recipes', (SELECT COUNT(*) FROM public.submitted_recipes WHERE status='approved'),
    'rejected_recipes', (SELECT COUNT(*) FROM public.submitted_recipes WHERE status='rejected'),
    'total_ingredients',(SELECT COUNT(*) FROM public.ingredients),
    'by_category', (
      SELECT json_agg(row_to_json(t)) FROM (
        SELECT category, COUNT(*) AS count FROM public.submitted_recipes
        WHERE status='approved' AND category IS NOT NULL
        GROUP BY category ORDER BY count DESC LIMIT 10
      ) t
    ),
    'by_status', (
      SELECT json_agg(row_to_json(t)) FROM (
        SELECT status, COUNT(*) AS count FROM public.submitted_recipes GROUP BY status
      ) t
    ),
    'by_month', (
      SELECT json_agg(row_to_json(t)) FROM (
        SELECT TO_CHAR(DATE_TRUNC('month', submitted_at), 'Mon YY') AS month,
               DATE_TRUNC('month', submitted_at) AS month_date, COUNT(*) AS count
        FROM public.submitted_recipes
        WHERE submitted_at >= NOW() - INTERVAL '12 months'
        GROUP BY month_date ORDER BY month_date
      ) t
    ),
    'top_contributors', (
      SELECT json_agg(row_to_json(t)) FROM (
        SELECT p.username, COUNT(sr.id) AS total,
               COUNT(sr.id) FILTER (WHERE sr.status='approved') AS approved
        FROM public.profiles p
        JOIN public.submitted_recipes sr ON sr.user_id = p.id
        GROUP BY p.id, p.username ORDER BY total DESC LIMIT 5
      ) t
    )
  ) INTO result;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_analytics() TO authenticated;

-- ── ADMIN — INGREDIENTS ───────────────────────────────────────────

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'admin_bulk_update_field' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.admin_bulk_update_field(
  p_ids   int[],
  p_field text,
  p_value text
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  allowed  text[] := ARRAY['Category','Sub Category','Vegan (Yes/No)','Vegetarian (Yes/No)',
                            'Allergen','Liquid (Yes/No)','CJ Recommended Brand','Unit','Notes'];
  affected int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NOT (p_field = ANY(allowed))
    THEN RAISE EXCEPTION 'Field not allowed: %', p_field; END IF;
  EXECUTE format('UPDATE public.ingredients SET %I = $1 WHERE "ID" = ANY($2)', p_field)
    USING p_value, p_ids;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_bulk_update_field(int[],text,text) TO authenticated;

-- Definitive bulk upsert — handles inserts, updates and restored-deleted rows
-- ── ADMIN — USERS ─────────────────────────────────────────────────

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'admin_set_user_active' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.admin_set_user_active(p_user_id uuid, p_active boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET is_active = p_active WHERE id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_user_active(uuid,boolean) TO authenticated;

-- ── TABLE PLANNER ─────────────────────────────────────────────────

-- get_my_events() removed: defined authoritatively in table_planner.sql

-- upsert_event() removed: defined authoritatively in table_planner.sql

-- save_event_layout() removed: defined authoritatively in table_planner.sql

-- delete_event() removed: defined authoritatively in table_planner.sql

-- get_event_guests() removed: defined authoritatively in table_planner.sql

-- upsert_guest() removed: defined authoritatively in table_planner.sql

-- assign_seat() removed: defined authoritatively in table_planner.sql

-- delete_guest() removed: defined authoritatively in table_planner.sql

-- Guest dietary card — public (no auth needed)
-- get_guest_card and submit_guest_dietary handle the public dietary-card link.
-- They are intentionally kept here (not in table_planner.sql) as they are
-- guest-facing public RPCs, not host/admin Table Planner operations.
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_guest_card' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_guest_card(p_token uuid)
RETURNS TABLE (
  guest_name           text,
  event_name           text,
  event_date           date,
  event_type           text,
  dietary_requirements jsonb,
  already_submitted    boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT g.name, e.name, e.event_date, e.event_type,
           COALESCE(g.dietary_requirements, '[]'::jsonb),
           COALESCE(g.dietary_submitted, false)
    FROM event_guests g
    JOIN public.events e ON e.id = g.event_id
    WHERE g.id = p_token;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_guest_card(uuid) TO anon, authenticated;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'submit_guest_dietary' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.submit_guest_dietary(p_token uuid, p_dietary jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE event_guests SET
    dietary_requirements = COALESCE(p_dietary, '[]'::jsonb),
    dietary_submitted    = true,
    dietary_submitted_at = now()
  WHERE id = p_token;
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_guest_dietary(uuid,jsonb) TO anon, authenticated;

-- ── COLLECTIONS ───────────────────────────────────────────────────

-- ── FAMILY PROFILES ───────────────────────────────────────────────

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_my_family_profiles' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_my_family_profiles()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(p ORDER BY
        CASE p.relationship
          WHEN 'self' THEN 1 WHEN 'partner' THEN 2 WHEN 'child' THEN 3
          WHEN 'toddler' THEN 4 WHEN 'baby' THEN 5 WHEN 'elderly' THEN 6 ELSE 7
        END, p.name)
     FROM family_profiles p WHERE p.user_id = auth.uid()),
    '[]'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_family_profiles() TO authenticated;

-- ── NOTIFICATIONS ─────────────────────────────────────────────────

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_notification_count' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_notification_count()
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN 0; END IF;
  RETURN (SELECT COUNT(*) FROM public.notifications
          WHERE user_id = auth.uid() AND read = false);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_notification_count() TO authenticated;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_my_notifications' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_my_notifications()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(n ORDER BY n.created_at DESC)
     FROM (SELECT * FROM notifications WHERE user_id = auth.uid()
           ORDER BY created_at DESC LIMIT 50) n),
    '[]'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_notifications() TO authenticated;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'mark_notification_read' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE id=p_id AND user_id=auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'mark_all_notifications_read' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE user_id=auth.uid() AND read=false;
END;
$$;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;

-- ── PAGE SETTINGS ─────────────────────────────────────────────────

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'get_page_settings' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.get_page_settings()
RETURNS TABLE (page_id text, visibility text, message text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY SELECT ps.page_id, ps.visibility, ps.message
    FROM public.page_settings ps ORDER BY ps.page_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_page_settings() TO anon, authenticated;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'set_page_visibility' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.set_page_visibility(
  p_page_id    text,
  p_visibility text,
  p_message    text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.page_settings (page_id, visibility, message)
  VALUES (p_page_id, p_visibility, COALESCE(p_message,''))
  ON CONFLICT (page_id) DO UPDATE
    SET visibility=p_visibility, message=COALESCE(p_message,'');
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_page_visibility(text,text,text) TO authenticated;

-- Orphan drops removed

-- ── is_username_taken — used by signup form ────────────────────────────
DROP FUNCTION IF EXISTS public.is_username_taken(text);
CREATE FUNCTION public.is_username_taken(uname text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE LOWER(username) = LOWER(TRIM(uname))
  );
END; $$;
REVOKE ALL ON FUNCTION public.is_username_taken(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.is_username_taken(text) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');
