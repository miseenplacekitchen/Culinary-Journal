-- ======================================================================
-- THE CULINARY JOURNAL — FULL DATABASE SETUP
-- Generated: 2026-06-05 23:57 UTC
-- Source: database/manifest.json → database/build-setup.py
--
-- Run this ONCE in Supabase Dashboard → SQL Editor on a fresh project.
-- Do NOT run 00-drop-functions.sql or archived files.
-- ======================================================================


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/01-schema.sql  [schema] owner=core
-- ──────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 01-schema.sql
-- All tables, RLS policies, grants and storage bucket.
-- Run this FIRST on a fresh Supabase project.
-- Safe to re-run — every statement is idempotent.
-- ═══════════════════════════════════════════════════════════════

-- ── GRANTS (must come first) ──────────────────────────────────────
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- ── 1. PROFILES ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id                  uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  username            text UNIQUE NOT NULL,
  full_name           text NOT NULL,
  email               text NOT NULL,
  is_admin            boolean     DEFAULT false,
  is_active           boolean     DEFAULT true,
  theme_preference    text        DEFAULT 'midnight-slate',
  avatar_url          text,
  dietary_preferences text[]      DEFAULT '{}',
  allergies           text[]      DEFAULT '{}',
  health_conditions   text[]      DEFAULT '{}',
  cooking_style       text        DEFAULT '',
  font_size           text        DEFAULT 'medium',
  created_at          timestamptz DEFAULT now(),
  last_seen           timestamptz DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

DROP POLICY IF EXISTS "Users can read own profile"    ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile"  ON public.profiles;
DROP POLICY IF EXISTS "Admin can read all profiles"   ON public.profiles;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- ── 2. SUBMITTED RECIPES ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.submitted_recipes (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid        REFERENCES auth.users(id),
  recipe_name         text        NOT NULL,
  native_title        text        DEFAULT '',
  category            text,
  spice_level         text        DEFAULT 'Not Applicable',
  origin_continent    text,
  origin_country      text,
  origin_state        text,
  prep_time_minutes   integer     DEFAULT 0,
  cook_time_minutes   integer     DEFAULT 0,
  servings            integer     DEFAULT 1,
  dietary_tags        text[]      DEFAULT '{}',
  health_tags         text[]      DEFAULT '{}',
  occasion_tags       text[]      DEFAULT '{}',
  style_tags          text[]      DEFAULT '{}',
  ingredients         jsonb,
  method              jsonb,
  cooking_notes       text        DEFAULT '',
  source_type         text        DEFAULT 'Original',
  credit_name         text,
  credit_handle       text,
  credit_url          text,
  visibility          text        DEFAULT 'Public',
  personal_notes      text,
  status              text        DEFAULT 'pending',
  submitted_at        timestamptz DEFAULT now(),
  reviewed_at         timestamptz,
  reviewer_notes      text        DEFAULT '',
  introduction        text        DEFAULT '',
  image_url           text        DEFAULT '',
  sweet_level         text        DEFAULT 'Not Applicable',
  difficulty          text        DEFAULT '',
  meal_type_tags      text[]      DEFAULT '{}',
  flavor_profile_tags text[]      DEFAULT '{}',
  equipment           jsonb       DEFAULT '[]',
  cooking_methods     jsonb       DEFAULT '[]',
  description         text        DEFAULT ''
);
ALTER TABLE public.submitted_recipes ENABLE ROW LEVEL SECURITY;
GRANT SELECT             ON public.submitted_recipes TO anon;
GRANT SELECT, INSERT, UPDATE ON public.submitted_recipes TO authenticated;

DROP POLICY IF EXISTS "Users can insert own recipes"               ON public.submitted_recipes;
DROP POLICY IF EXISTS "Users can submit recipes"                   ON public.submitted_recipes;
DROP POLICY IF EXISTS "Users can view own submissions"             ON public.submitted_recipes;
DROP POLICY IF EXISTS "Users can update own pending submissions"   ON public.submitted_recipes;
DROP POLICY IF EXISTS "Users can update own submissions"           ON public.submitted_recipes;
DROP POLICY IF EXISTS "Anyone can read approved public recipes"    ON public.submitted_recipes;
DROP POLICY IF EXISTS "Users can insert own recipes"               ON public.submitted_recipes;

CREATE POLICY "Users can insert own recipes"
  ON public.submitted_recipes FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id AND status = 'pending');

CREATE POLICY "Users can view own submissions"
  ON public.submitted_recipes FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own submissions"
  ON public.submitted_recipes FOR UPDATE TO authenticated
  USING (auth.uid() = user_id AND status = 'pending')
  WITH CHECK (auth.uid() = user_id AND status = 'pending');

CREATE POLICY "Anyone can read approved public recipes"
  ON public.submitted_recipes FOR SELECT
  USING (status = 'approved' AND visibility = 'Public');

-- ── 3. INGREDIENTS ───────────────────────────────────────────────
-- Uses original CSV column names (spaces + capitals) — do not rename.
CREATE TABLE IF NOT EXISTS public.ingredients (
  "ID"                       serial PRIMARY KEY,
  "Ingredient Name"          text,
  "Also Known As"            text,
  "Category"                 text,
  "Sub Category"             text,
  "Standard Qty"             text,
  "Standard Weight (g or ml)" numeric,
  "Unit"                     text,
  "Liquid (Yes/No)"          text,
  "CJ Recommended Brand"     text,
  "Allergen"                 text,
  "Vegan (Yes/No)"           text,
  "Vegetarian (Yes/No)"      text,
  "Notes"                    text,
  extra_fields               jsonb DEFAULT '{}'
);
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.ingredients TO anon, authenticated;

DROP POLICY IF EXISTS "Anyone can read ingredients"              ON public.ingredients;
DROP POLICY IF EXISTS "Authenticated users can read ingredients" ON public.ingredients;

CREATE POLICY "Anyone can read ingredients"
  ON public.ingredients FOR SELECT USING (true);

-- ── 4. SUBSTITUTIONS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.substitutions (
  id              serial PRIMARY KEY,
  category        text NOT NULL,
  original        text NOT NULL,
  substitute      text NOT NULL,
  ratio           text,
  notes           text,
  dietary_benefit text
);
ALTER TABLE public.substitutions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.substitutions TO anon, authenticated;

DROP POLICY IF EXISTS "Anyone can read substitutions" ON public.substitutions;
CREATE POLICY "Anyone can read substitutions"
  ON public.substitutions FOR SELECT USING (true);

-- ── 5. EVENTS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  event_type  text        DEFAULT 'Dinner Party',
  event_date  date,
  venue_name  text,
  notes       text,
  layout      jsonb       DEFAULT '{"tables":[]}',
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.events TO authenticated;

DROP POLICY IF EXISTS "Users manage own events" ON public.events;
CREATE POLICY "Users manage own events"
  ON public.events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── 6. GUESTS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guests_legacy (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id              uuid REFERENCES public.events(id) ON DELETE CASCADE,
  name                  text NOT NULL,
  dietary_requirements  text[]      DEFAULT '{}',
  rsvp_status           text        DEFAULT 'pending',
  group_name            text,
  seat_assignment       text,
  plus_one              boolean     DEFAULT false,
  plus_one_name         text,
  notes                 text,
  dietary_submitted     boolean     DEFAULT false,
  dietary_submitted_at  timestamptz,
  created_at            timestamptz DEFAULT now()
);
-- event_guests table, RLS, and policies are in table_planner.sql
-- guests_legacy above is kept for reference only and is not used by any frontend.

-- ── 7. COLLECTIONS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.collections (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text        DEFAULT '',
  emoji       text        DEFAULT '📁',
  is_public   boolean     DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.collections TO authenticated;

DROP POLICY IF EXISTS "Users manage own collections"  ON public.collections;
DROP POLICY IF EXISTS "Public collections readable"   ON public.collections;

CREATE POLICY "Users manage own collections"
  ON public.collections FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Public collections readable"
  ON public.collections FOR SELECT TO anon, authenticated
  USING (is_public = true);

-- ── 8. COLLECTION RECIPES ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.collection_recipes (
  collection_id uuid REFERENCES public.collections(id)       ON DELETE CASCADE,
  recipe_id     uuid REFERENCES public.submitted_recipes(id) ON DELETE CASCADE,
  added_at      timestamptz DEFAULT now(),
  PRIMARY KEY (collection_id, recipe_id)
);
ALTER TABLE public.collection_recipes ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON public.collection_recipes TO authenticated;

DROP POLICY IF EXISTS "Users manage own collection recipes" ON public.collection_recipes;
CREATE POLICY "Users manage own collection recipes"
  ON public.collection_recipes FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.collections c
    WHERE c.id = collection_id AND c.user_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.collections c
    WHERE c.id = collection_id AND c.user_id = auth.uid()
  ));

-- ── 9. FAMILY PROFILES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.family_profiles (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name              text NOT NULL,
  relationship      text        DEFAULT 'guest',
  age_group         text        DEFAULT 'adult',
  allergies         jsonb       NOT NULL DEFAULT '[]',
  spice_preference  text        DEFAULT 'medium',
  dietary_needs     jsonb       NOT NULL DEFAULT '[]',
  health_conditions text[]      DEFAULT '{}',
  notes             text,
  created_at        timestamptz DEFAULT now()
);
ALTER TABLE public.family_profiles ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.family_profiles TO authenticated;

DROP POLICY IF EXISTS "Users manage own family profiles" ON public.family_profiles;
CREATE POLICY "Users manage own family profiles"
  ON public.family_profiles FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── 10. NOTIFICATIONS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  type        text NOT NULL,
  recipe_id   uuid,
  recipe_name text,
  message     text,
  read        boolean     DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;

DROP POLICY IF EXISTS "Users see own notifications" ON public.notifications;
CREATE POLICY "Users see own notifications"
  ON public.notifications FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── 11. PAGE SETTINGS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.page_settings (
  page_id    text PRIMARY KEY,
  visibility text DEFAULT 'live',
  message    text DEFAULT ''
);
ALTER TABLE public.page_settings ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.page_settings TO anon, authenticated;

DROP POLICY IF EXISTS "Public read page settings" ON public.page_settings;
CREATE POLICY "Public read page settings"
  ON public.page_settings FOR SELECT TO anon, authenticated USING (true);

-- ── 12. STORAGE BUCKET ───────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'recipe-images', 'recipe-images', true, 5242880,
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public             = EXCLUDED.public,
  file_size_limit    = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public can read recipe images"               ON storage.objects;
DROP POLICY IF EXISTS "Users can upload recipe images to own folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own recipe images"          ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own recipe images"          ON storage.objects;

CREATE POLICY "Public can read recipe images"
  ON storage.objects FOR SELECT USING (bucket_id = 'recipe-images');

CREATE POLICY "Users can upload recipe images to own folder"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'recipe-images'
    AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update own recipe images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'recipe-images'
    AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete own recipe images"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'recipe-images'
    AND (storage.foldername(name))[1] = auth.uid()::text);


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/sync-submitted-recipes-columns.sql  [patch] owner=schema
-- NOTE: Column guards folded into setup until merged into 01-schema
-- ──────────────────────────────────────────────────────────────────

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

-- Also ensure reviewer_notes exists (used by admin_review_recipe)
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS reviewer_notes           text;
ALTER TABLE submitted_recipes ADD COLUMN IF NOT EXISTS reviewed_at              timestamptz;

SELECT 'submitted_recipes columns synced' AS status;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/02-functions.sql  [functions] owner=core
-- ──────────────────────────────────────────────────────────────────

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
  created_at          timestamptz
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
           u.created_at
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

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'admin_review_recipe' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id     uuid,
  p_status text,
  p_notes  text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending')
    THEN RAISE EXCEPTION 'Invalid status: %', p_status; END IF;
  UPDATE public.submitted_recipes
     SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
   WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid,text,text) TO authenticated;

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
CREATE FUNCTION public.is_username_taken(p_username text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE LOWER(username) = LOWER(p_username)
  );
END; $$;
REVOKE ALL ON FUNCTION public.is_username_taken(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.is_username_taken(text) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/03-seed.sql  [seed] owner=core
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- IMPORTANT: Admin email is miseenplacekitchen.official@gmail.com
-- If your admin account uses a different email, update it here AND
-- in any profile row in Supabase before signing in as admin.
-- ══════════════════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 03-seed.sql
-- Seed data only. Run AFTER 01-schema.sql and 02-functions.sql.
-- Safe to re-run — all inserts use ON CONFLICT DO NOTHING.
-- ═══════════════════════════════════════════════════════════════

-- ── SUBSTITUTIONS ────────────────────────────────────────────────
INSERT INTO public.substitutions (category, original, substitute, ratio, notes, dietary_benefit) VALUES
-- BAKING
('Baking','Butter','Coconut Oil','1:1','Adds slight coconut flavour. Best for muffins and quick breads.','Vegan, Dairy-Free'),
('Baking','Butter','Applesauce','1:1','Reduces fat, adds moisture and mild sweetness. Best in cakes.','Vegan, Lower Fat'),
('Baking','Eggs','Flax Egg (1 tbsp ground flax + 3 tbsp water)','1 egg = 1 flax egg','Let sit 5 minutes until gel forms. Best in dense baked goods.','Vegan'),
('Baking','Eggs','Chia Egg (1 tbsp chia seeds + 3 tbsp water)','1 egg = 1 chia egg','Let sit 10 minutes. Slightly crunchier texture.','Vegan'),
('Baking','Eggs','Unsweetened Applesauce','1 egg = ¼ cup','Best in moist cakes and muffins. Not suitable for meringues.','Vegan'),
('Baking','Baking Powder','Baking Soda + Cream of Tartar','¼ tsp baking soda + ½ tsp cream of tartar = 1 tsp','Use immediately after mixing.',''),
('Baking','Plain Flour','Almond Flour','1:1 by weight','Denser texture. Adds nutty flavour. Not suitable for bread.','Gluten-Free'),
('Baking','Plain Flour','Gluten-Free Plain Flour Blend','1:1','Best results with blends that include xanthan gum.','Gluten-Free'),
('Baking','Buttermilk','Milk + White Vinegar','1 cup milk + 1 tbsp vinegar','Let stand 5 minutes until slightly curdled.',''),
('Baking','Buttermilk','Plain Yoghurt thinned with milk','3:1 ratio','Use full-fat yoghurt for best results.',''),
-- DAIRY
('Dairy','Milk','Oat Milk','1:1','Closest to whole milk in baking. Mild flavour.','Vegan, Dairy-Free'),
('Dairy','Milk','Almond Milk','1:1','Thinner consistency. Use unsweetened for savoury dishes.','Vegan, Dairy-Free'),
('Dairy','Milk','Soy Milk','1:1','Highest protein of plant milks. Best for baking.','Vegan, Dairy-Free'),
('Dairy','Milk','Coconut Milk (canned, full fat)','1:1','Richer and creamier. Best in soups, curries and desserts.','Vegan, Dairy-Free'),
('Dairy','Heavy Cream','Coconut Cream','1:1','Chill overnight, use solid part. Whips well. Slight coconut flavour.','Vegan, Dairy-Free'),
('Dairy','Heavy Cream','Cashew Cream','1:1','Blend soaked cashews with water until smooth.','Vegan, Dairy-Free'),
('Dairy','Butter','Vegan Butter Block','1:1','Best for baking where butter flavour matters.','Vegan, Dairy-Free'),
('Dairy','Yoghurt','Coconut Yoghurt','1:1','Full-fat works best. Slight coconut flavour.','Vegan, Dairy-Free'),
('Dairy','Cheese (soft)','Cashew Cheese','1:1','Blend soaked cashews with nutritional yeast, lemon and salt.','Vegan, Dairy-Free'),
-- OILS & FATS
('Oils & Fats','Olive Oil','Avocado Oil','1:1','Higher smoke point. Neutral flavour. Ideal for high-heat cooking.',''),
('Oils & Fats','Olive Oil','Coconut Oil','1:1','Adds coconut flavour. Solid at room temperature.','Vegan'),
('Oils & Fats','Vegetable Oil','Sunflower Oil','1:1','Neutral flavour. Good all-purpose substitute.',''),
('Oils & Fats','Butter','Olive Oil','¾ cup per 1 cup butter','Reduces saturated fat. Changes texture slightly.','Dairy-Free'),
('Oils & Fats','Ghee','Clarified Butter','1:1','Nearly identical. Same smoke point and flavour profile.',''),
('Oils & Fats','Ghee','Coconut Oil','1:1','Best for Indian cooking. Adds slight coconut note.','Vegan, Dairy-Free'),
-- SPICES
('Spices','Fresh Ginger','Ground Ginger','1 tsp fresh = ¼ tsp ground','Ground is more concentrated. Less aromatic than fresh.',''),
('Spices','Fresh Garlic','Garlic Powder','1 clove = ⅛ tsp powder','Less pungent than fresh. Add at start of cooking.',''),
('Spices','Fresh Turmeric','Ground Turmeric','1 tsp fresh = ¼ tsp ground','Ground is more concentrated. Earthy flavour.',''),
('Spices','Smoked Paprika','Sweet Paprika + drop of Liquid Smoke','1:1 paprika + 1 drop','Use liquid smoke sparingly — a little goes a long way.',''),
('Spices','Chilli Flakes','Cayenne Pepper','½ tsp cayenne = 1 tsp flakes','Cayenne is hotter. Adjust to taste.',''),
('Spices','Cumin Seeds','Ground Cumin','1 tsp seeds = ¾ tsp ground','Toast ground cumin briefly to develop flavour.',''),
('Spices','Coriander Seeds','Ground Coriander','1 tsp seeds = ¾ tsp ground','',''),
-- VINEGARS
('Vinegars','White Wine Vinegar','Apple Cider Vinegar','1:1','Slightly fruity. Works well in dressings and marinades.',''),
('Vinegars','Red Wine Vinegar','Balsamic Vinegar','1:1 but use less','Sweeter and thicker. Not suitable for delicate dressings.',''),
('Vinegars','Apple Cider Vinegar','Lemon Juice','1:1','Brighter, more citrus flavour. Less complex.',''),
('Vinegars','Rice Wine Vinegar','White Wine Vinegar','1:1','White wine vinegar is slightly more acidic.',''),
-- SWEETENERS
('Sweeteners','White Sugar','Honey','¾ cup honey per 1 cup sugar','Reduce liquid in recipe by ¼ cup. Adds moisture and distinct flavour.',''),
('Sweeteners','White Sugar','Maple Syrup','¾ cup per 1 cup sugar','Reduce other liquids slightly. Adds warm flavour.','Vegan'),
('Sweeteners','White Sugar','Coconut Sugar','1:1','Slightly less sweet. Contains trace minerals. Lower glycaemic index.',''),
('Sweeteners','White Sugar','Stevia','1 tsp per 1 cup sugar','Very sweet — use sparingly. Does not caramelise.','Diabetic Friendly'),
('Sweeteners','Brown Sugar','Coconut Sugar','1:1','Similar caramel notes. Slightly less sweet.',''),
('Sweeteners','Icing Sugar','Blended Coconut Sugar','1:1','Blend coconut sugar until fine. May be slightly less white.','')
ON CONFLICT DO NOTHING;

-- ── PAGE SETTINGS ─────────────────────────────────────────────────
INSERT INTO public.page_settings (page_id, visibility) VALUES
  ('recipes',         'live'),
  ('submit-recipe',   'live'),
  ('recipe-page',     'live'),
  ('grocery',         'live'),
  ('meal-planner',    'live'),
  ('pantry',          'live'),
  ('table-planner',   'live'),
  ('print-studio',    'live'),
  ('collections',     'live'),
  ('family-profiles', 'live'),
  ('baby',            'live'),
  ('preservation',    'live'),
  ('conversions',     'live'),
  ('chefs',           'live'),
  ('search',          'live'),
  ('my-dashboard',    'live'),
  ('profile',         'live')
ON CONFLICT (page_id) DO NOTHING;

-- ── GRANT ADMIN ACCESS ────────────────────────────────────────────
-- Sets your account as admin. Run once after signing up.
UPDATE public.profiles
   SET is_admin = true
 WHERE email = 'miseenplacekitchen.official@gmail.com';


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/04-auth-triggers.sql  [triggers] owner=core
-- ──────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 04-auth-triggers.sql
-- Two missing pieces that were never written.
-- Run in Supabase → SQL Editor AFTER the other 4 files.
-- ═══════════════════════════════════════════════════════════════

-- ── 2. handle_new_user trigger ───────────────────────────────────
-- Fires automatically when a new user is created in auth.users.
-- Creates the matching profile row using metadata from signup.
-- This is what connects Supabase Auth to the profiles table.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    NEW.email
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/05-diary.sql  [feature] owner=diary
-- ──────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 05-diary.sql
-- Diary entries table + RPCs
-- Run in Supabase SQL Editor after 04-auth-triggers.sql
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.diary_entries (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  entry_date  date        NOT NULL,
  title       text        DEFAULT '',
  content     text        DEFAULT '',
  entry_type  text        DEFAULT 'general',
  mood        text        DEFAULT '',
  tags        text[]      DEFAULT '{}',
  is_private  boolean     DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

ALTER TABLE public.diary_entries ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.diary_entries TO authenticated;

DROP POLICY IF EXISTS "Users manage own diary" ON public.diary_entries;
CREATE POLICY "Users manage own diary"
  ON public.diary_entries FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Get entries for a specific month
DROP FUNCTION IF EXISTS public.get_my_diary_entries(int, int);
CREATE FUNCTION public.get_my_diary_entries(p_year int, p_month int)
RETURNS SETOF public.diary_entries
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT * FROM public.diary_entries
    WHERE user_id = auth.uid()
      AND EXTRACT(YEAR  FROM entry_date) = p_year
      AND EXTRACT(MONTH FROM entry_date) = p_month
    ORDER BY entry_date DESC, created_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_diary_entries(int,int) TO authenticated;

-- Get all entries for search
DROP FUNCTION IF EXISTS public.search_my_diary(text);
CREATE FUNCTION public.search_my_diary(p_query text)
RETURNS SETOF public.diary_entries
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT * FROM public.diary_entries
    WHERE user_id = auth.uid()
      AND (title ILIKE '%'||p_query||'%' OR content ILIKE '%'||p_query||'%'
           OR p_query = ANY(tags))
    ORDER BY entry_date DESC LIMIT 50;
END;
$$;
GRANT EXECUTE ON FUNCTION public.search_my_diary(text) TO authenticated;

-- Upsert a diary entry
DROP FUNCTION IF EXISTS public.upsert_diary_entry(uuid,date,text,text,text,text,text[],boolean);
CREATE FUNCTION public.upsert_diary_entry(
  p_id         uuid    DEFAULT NULL,
  p_date       date    DEFAULT CURRENT_DATE,
  p_title      text    DEFAULT '',
  p_content    text    DEFAULT '',
  p_type       text    DEFAULT 'general',
  p_mood       text    DEFAULT '',
  p_tags       text[]  DEFAULT '{}',
  p_is_private boolean DEFAULT true
)
RETURNS public.diary_entries
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result public.diary_entries;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.diary_entries
      (user_id, entry_date, title, content, entry_type, mood, tags, is_private)
    VALUES (auth.uid(), p_date, p_title, p_content, p_type, p_mood,
            COALESCE(p_tags,'{}'), p_is_private)
    RETURNING * INTO result;
  ELSE
    UPDATE public.diary_entries SET
      entry_date = p_date, title = p_title, content = p_content,
      entry_type = p_type, mood = p_mood, tags = COALESCE(p_tags,'{}'),
      is_private = p_is_private, updated_at = now()
    WHERE id = p_id AND user_id = auth.uid()
    RETURNING * INTO result;
  END IF;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_diary_entry(uuid,date,text,text,text,text,text[],boolean) TO authenticated;

-- Delete a diary entry
DROP FUNCTION IF EXISTS public.delete_diary_entry(uuid);
CREATE FUNCTION public.delete_diary_entry(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.diary_entries WHERE id = p_id AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_diary_entry(uuid) TO authenticated;

-- Diary stats (streak + count)
DROP FUNCTION IF EXISTS public.get_diary_stats();
CREATE FUNCTION public.get_diary_stats()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  total_count  bigint;
  this_month   bigint;
  streak       int := 0;
  check_date   date := CURRENT_DATE;
BEGIN
  IF auth.uid() IS NULL THEN RETURN '{}'; END IF;
  SELECT COUNT(*) INTO total_count FROM public.diary_entries WHERE user_id = auth.uid();
  SELECT COUNT(*) INTO this_month  FROM public.diary_entries
    WHERE user_id = auth.uid()
      AND EXTRACT(YEAR FROM entry_date)  = EXTRACT(YEAR FROM CURRENT_DATE)
      AND EXTRACT(MONTH FROM entry_date) = EXTRACT(MONTH FROM CURRENT_DATE);
  LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.diary_entries
      WHERE user_id = auth.uid() AND entry_date = check_date
    );
    streak     := streak + 1;
    check_date := check_date - 1;
  END LOOP;
  RETURN json_build_object('total', total_count, 'this_month', this_month, 'streak', streak);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_diary_stats() TO authenticated;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/06-culinary-life.sql  [feature] owner=culinary-life
-- ──────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 06-culinary-life.sql
-- Culinary Life system: cooking events, recipe mentions, 
-- milestones, and the discovery engine.
-- Run after 05-diary.sql
-- ═══════════════════════════════════════════════════════════════

-- ── COOKING EVENTS ──────────────────────────────────────────────
-- Passive capture: every time a user marks a recipe as cooked.
-- This is the foundation of the "system discovers" model.
CREATE TABLE IF NOT EXISTS public.cooking_events (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_id    uuid        REFERENCES public.submitted_recipes(id) ON DELETE SET NULL,
  recipe_name  text        NOT NULL,  -- denormalised for resilience
  cooked_at    date        NOT NULL DEFAULT CURRENT_DATE,
  notes        text        DEFAULT '',
  servings     int         DEFAULT 1,
  occasion     text        DEFAULT '', -- e.g. 'weeknight', 'birthday', 'christmas'
  rating       int         CHECK (rating BETWEEN 1 AND 5),
  created_at   timestamptz DEFAULT now()
);
ALTER TABLE public.cooking_events ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cooking_events TO authenticated;
DROP POLICY IF EXISTS "Users manage own cooking events" ON public.cooking_events;
CREATE POLICY "Users manage own cooking events"
  ON public.cooking_events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS cooking_events_user_date ON public.cooking_events(user_id, cooked_at DESC);
CREATE INDEX IF NOT EXISTS cooking_events_recipe    ON public.cooking_events(recipe_id);

-- ── DIARY ↔ RECIPE LINKS ────────────────────────────────────────
-- When a diary entry mentions a recipe, record the link.
CREATE TABLE IF NOT EXISTS public.diary_recipe_mentions (
  diary_entry_id uuid REFERENCES public.diary_entries(id) ON DELETE CASCADE,
  recipe_id      uuid REFERENCES public.submitted_recipes(id) ON DELETE CASCADE,
  user_id        uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY (diary_entry_id, recipe_id)
);
ALTER TABLE public.diary_recipe_mentions ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON public.diary_recipe_mentions TO authenticated;
DROP POLICY IF EXISTS "Users manage own mentions" ON public.diary_recipe_mentions;
CREATE POLICY "Users manage own mentions"
  ON public.diary_recipe_mentions FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── USER MILESTONES ──────────────────────────────────────────────
-- Auto-generated milestones. System writes these when thresholds hit.
CREATE TABLE IF NOT EXISTS public.user_milestones (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  milestone    text        NOT NULL,  -- e.g. 'first_recipe', '50_cooks', 'first_print'
  label        text        NOT NULL,  -- human-readable
  achieved_at  timestamptz DEFAULT now(),
  data         jsonb       DEFAULT '{}'
);
ALTER TABLE public.user_milestones ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON public.user_milestones TO authenticated;
DROP POLICY IF EXISTS "Users read own milestones" ON public.user_milestones;
CREATE POLICY "Users read own milestones"
  ON public.user_milestones FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "System inserts milestones" ON public.user_milestones;
CREATE POLICY "System inserts milestones"
  ON public.user_milestones FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE UNIQUE INDEX IF NOT EXISTS milestones_unique ON public.user_milestones(user_id, milestone);

-- ═══════════════════════════════════════════════════════════════
-- RPC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- ── LOG A COOKING EVENT ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.log_cooking_event(uuid, text, date, text, int, text, int);
CREATE FUNCTION public.log_cooking_event(
  p_recipe_id   uuid    DEFAULT NULL,
  p_recipe_name text    DEFAULT '',
  p_cooked_at   date    DEFAULT CURRENT_DATE,
  p_notes       text    DEFAULT '',
  p_servings    int     DEFAULT 1,
  p_occasion    text    DEFAULT '',
  p_rating      int     DEFAULT NULL
) RETURNS public.cooking_events
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.cooking_events;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  INSERT INTO public.cooking_events
    (user_id, recipe_id, recipe_name, cooked_at, notes, servings, occasion, rating)
  VALUES
    (auth.uid(), p_recipe_id, p_recipe_name, p_cooked_at,
     p_notes, p_servings, p_occasion, p_rating)
  RETURNING * INTO result;
  -- Check and award milestones
  PERFORM check_cooking_milestones();
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_cooking_event(uuid,text,date,text,int,text,int) TO authenticated;

-- ── CULINARY LIFE OVERVIEW ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_culinary_life();
CREATE FUNCTION public.get_culinary_life()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid               uuid := auth.uid();
  total_cooks       bigint;
  this_year_cooks   bigint;
  this_month_cooks  bigint;
  unique_recipes    bigint;
  diary_count       bigint;
  collection_count  bigint;
  recipe_count      bigint;
  this_year         int := EXTRACT(YEAR FROM CURRENT_DATE);
BEGIN
  IF uid IS NULL THEN RETURN '{}'; END IF;

  SELECT COUNT(*)                INTO total_cooks      FROM cooking_events WHERE user_id = uid;
  SELECT COUNT(*)                INTO this_year_cooks  FROM cooking_events WHERE user_id = uid AND EXTRACT(YEAR  FROM cooked_at) = this_year;
  SELECT COUNT(*)                INTO this_month_cooks FROM cooking_events WHERE user_id = uid AND EXTRACT(YEAR  FROM cooked_at) = this_year AND EXTRACT(MONTH FROM cooked_at) = EXTRACT(MONTH FROM CURRENT_DATE);
  SELECT COUNT(DISTINCT recipe_name) INTO unique_recipes FROM cooking_events WHERE user_id = uid;
  SELECT COUNT(*)                INTO diary_count      FROM diary_entries  WHERE user_id = uid;
  SELECT COUNT(*)                INTO collection_count FROM collections    WHERE user_id = uid;
  SELECT COUNT(*)                INTO recipe_count     FROM submitted_recipes WHERE user_id = uid AND status = 'approved';

  RETURN json_build_object(
    'total_cooks',       total_cooks,
    'this_year_cooks',   this_year_cooks,
    'this_month_cooks',  this_month_cooks,
    'unique_recipes',    unique_recipes,
    'diary_entries',     diary_count,
    'collections',       collection_count,
    'published_recipes', recipe_count
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_culinary_life() TO authenticated;

-- ── FAMILY FAVOURITES (system-discovered) ───────────────────────
DROP FUNCTION IF EXISTS public.get_family_favourites(int);
CREATE FUNCTION public.get_family_favourites(p_limit int DEFAULT 10)
RETURNS TABLE (
  recipe_id    uuid,
  recipe_name  text,
  cook_count   bigint,
  last_cooked  date,
  avg_rating   numeric,
  diary_mentions bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT
      ce.recipe_id,
      ce.recipe_name,
      COUNT(*) AS cook_count,
      MAX(ce.cooked_at) AS last_cooked,
      ROUND(AVG(ce.rating), 1) AS avg_rating,
      COUNT(DISTINCT drm.diary_entry_id) AS diary_mentions
    FROM cooking_events ce
    LEFT JOIN diary_recipe_mentions drm ON drm.recipe_id = ce.recipe_id AND drm.user_id = ce.user_id
    WHERE ce.user_id = auth.uid()
      AND ce.recipe_id IS NOT NULL
    GROUP BY ce.recipe_id, ce.recipe_name
    ORDER BY cook_count DESC, diary_mentions DESC
    LIMIT p_limit;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_family_favourites(int) TO authenticated;

-- ── CULINARY TIMELINE ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_culinary_timeline(int);
CREATE FUNCTION public.get_culinary_timeline(p_limit int DEFAULT 20)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid uuid := auth.uid();
  timeline json;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT json_agg(events ORDER BY event_date DESC)
  INTO timeline
  FROM (
    -- Cooking events
    SELECT
      'cook'         AS event_type,
      id::text       AS source_id,
      cooked_at      AS event_date,
      recipe_name    AS label,
      notes          AS detail,
      rating::text   AS meta,
      occasion       AS context
    FROM cooking_events
    WHERE user_id = uid
    UNION ALL
    -- Diary entries
    SELECT
      'diary'        AS event_type,
      id::text       AS source_id,
      entry_date     AS event_date,
      COALESCE(NULLIF(title,''), 'Journal Entry') AS label,
      LEFT(content, 100) AS detail,
      entry_type     AS meta,
      mood           AS context
    FROM diary_entries
    WHERE user_id = uid
    UNION ALL
    -- Recipe submissions
    SELECT
      'recipe'       AS event_type,
      id::text       AS source_id,
      submitted_at::date AS event_date,
      recipe_name    AS label,
      status         AS detail,
      category       AS meta,
      ''             AS context
    FROM submitted_recipes
    WHERE user_id = uid
    UNION ALL
    -- Milestones
    SELECT
      'milestone'    AS event_type,
      NULL::text     AS source_id,
      achieved_at::date AS event_date,
      label          AS label,
      milestone      AS detail,
      ''             AS meta,
      ''             AS context
    FROM user_milestones
    WHERE user_id = uid
    LIMIT p_limit
  ) events;
  RETURN COALESCE(timeline, '[]'::json);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_culinary_timeline(int) TO authenticated;

-- ── YEAR IN REVIEW ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_year_in_review(int);
CREATE FUNCTION public.get_year_in_review(p_year int DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid    uuid := auth.uid();
  yr     int  := COALESCE(p_year, EXTRACT(YEAR FROM CURRENT_DATE)::int);
  result json;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT json_build_object(
    'year', yr,
    'total_cooks',
      (SELECT COUNT(*) FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr),
    'unique_recipes',
      (SELECT COUNT(DISTINCT recipe_name) FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr),
    'diary_entries',
      (SELECT COUNT(*) FROM diary_entries WHERE user_id=uid AND EXTRACT(YEAR FROM entry_date)=yr),
    'top_recipe',
      (SELECT recipe_name FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr
       GROUP BY recipe_name ORDER BY COUNT(*) DESC LIMIT 1),
    'top_occasion',
      (SELECT occasion FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr
       AND occasion != '' GROUP BY occasion ORDER BY COUNT(*) DESC LIMIT 1),
    'months',
      (SELECT json_agg(json_build_object('month', m, 'cooks', c) ORDER BY m)
       FROM (SELECT EXTRACT(MONTH FROM cooked_at)::int AS m, COUNT(*) AS c
             FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr
             GROUP BY m) monthly)
  ) INTO result;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_year_in_review(int) TO authenticated;

-- ── RECENT COOKING ACTIVITY ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_recent_cooks(int);
CREATE FUNCTION public.get_recent_cooks(p_limit int DEFAULT 12)
RETURNS SETOF public.cooking_events
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT * FROM cooking_events
    WHERE user_id = auth.uid()
    ORDER BY cooked_at DESC, created_at DESC
    LIMIT p_limit;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_recent_cooks(int) TO authenticated;

-- ── MILESTONE CHECKER (called internally) ───────────────────────
DROP FUNCTION IF EXISTS public.check_cooking_milestones();
CREATE FUNCTION public.check_cooking_milestones()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid        uuid := auth.uid();
  cook_count bigint;
BEGIN
  SELECT COUNT(*) INTO cook_count FROM cooking_events WHERE user_id = uid;
  -- First cook
  IF cook_count = 1 THEN
    INSERT INTO user_milestones(user_id, milestone, label)
    VALUES (uid, 'first_cook', 'First recipe cooked!') ON CONFLICT DO NOTHING;
  END IF;
  -- 10 cooks
  IF cook_count = 10 THEN
    INSERT INTO user_milestones(user_id, milestone, label, data)
    VALUES (uid, '10_cooks', '10 recipes cooked', '{"count":10}') ON CONFLICT DO NOTHING;
  END IF;
  -- 50 cooks
  IF cook_count = 50 THEN
    INSERT INTO user_milestones(user_id, milestone, label, data)
    VALUES (uid, '50_cooks', '50 meals cooked — you''re on a roll', '{"count":50}') ON CONFLICT DO NOTHING;
  END IF;
  -- 100 cooks
  IF cook_count = 100 THEN
    INSERT INTO user_milestones(user_id, milestone, label, data)
    VALUES (uid, '100_cooks', '100 meals cooked', '{"count":100}') ON CONFLICT DO NOTHING;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_cooking_milestones() TO authenticated;

-- ── DELETE A COOKING EVENT ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.delete_cooking_event(uuid);
CREATE FUNCTION public.delete_cooking_event(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM cooking_events WHERE id = p_id AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_cooking_event(uuid) TO authenticated;

-- ── UPDATE COOKING EVENT (AP-03) ─────────────────────────────────
DROP FUNCTION IF EXISTS public.update_cooking_event(uuid, text, date, int, text);
CREATE FUNCTION public.update_cooking_event(
  p_id uuid, p_recipe_name text DEFAULT NULL, p_cooked_at date DEFAULT NULL,
  p_rating int DEFAULT NULL, p_notes text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE cooking_events SET
    recipe_name = COALESCE(NULLIF(p_recipe_name,''), recipe_name),
    cooked_at   = COALESCE(p_cooked_at, cooked_at),
    rating      = COALESCE(p_rating, rating),
    notes       = COALESCE(p_notes, notes)
  WHERE id = p_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found_or_not_yours'; END IF;
END; $$;
REVOKE ALL ON FUNCTION public.update_cooking_event(uuid, text, date, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_cooking_event(uuid, text, date, int, text) TO authenticated;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/table_planner.sql  [feature] owner=table-planner
-- ──────────────────────────────────────────────────────────────────

-- Drop old SETOF versions before creating jsonb versions
DROP FUNCTION IF EXISTS public.get_my_events();
DROP FUNCTION IF EXISTS public.get_event_guests(uuid);
DROP FUNCTION IF EXISTS public.get_my_events(uuid);

-- ══════════════════════════════════════════════════════════════════════
-- Table Planner — The Culinary Journal
-- Supports table-planner.html exactly
-- Tables: events, event_guests
-- RPCs: get_my_events, upsert_event, delete_event,
--        get_event_guests, upsert_guest, delete_guest,
--        assign_seat, save_event_layout
-- ══════════════════════════════════════════════════════════════════════

-- ── Events table ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       text NOT NULL,
  event_type text,
  event_date date,
  venue_name text,
  notes      text,
  layout     jsonb NOT NULL DEFAULT '{"tables":[]}',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);
-- Guards for existing events table
ALTER TABLE events ADD COLUMN IF NOT EXISTS user_id     uuid;
ALTER TABLE events ADD COLUMN IF NOT EXISTS name       text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_type  text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_date date;
ALTER TABLE events ADD COLUMN IF NOT EXISTS venue_name text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS notes      text;
ALTER TABLE events ADD COLUMN IF NOT EXISTS layout     jsonb;
ALTER TABLE events ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE events ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT NOW();

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own events" ON events;
CREATE POLICY "users manage own events" ON events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── Event guests table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS event_guests (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id             uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  dietary_requirements jsonb NOT NULL DEFAULT '[]',
  rsvp_status          text DEFAULT 'pending',
  group_name           text,
  plus_one             boolean NOT NULL DEFAULT false,
  plus_one_name        text,
  seat                 text,
  notes                text,
  created_at           timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS event_id             uuid;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS name                 text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS created_at             timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS dietary_requirements   jsonb NOT NULL DEFAULT '[]';
-- Migrate any existing text values to jsonb array
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='event_guests' AND column_name='dietary_requirements'
    AND data_type='text'
  ) THEN
    ALTER TABLE event_guests ALTER COLUMN dietary_requirements TYPE jsonb
      USING CASE WHEN dietary_requirements IS NULL OR dietary_requirements = ''
                 THEN '[]'::jsonb
                 ELSE to_jsonb(string_to_array(dietary_requirements, ','))
            END;
    ALTER TABLE event_guests ALTER COLUMN dietary_requirements SET DEFAULT '[]';
    ALTER TABLE event_guests ALTER COLUMN dietary_requirements SET NOT NULL;
  END IF;
END $$;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS dietary_submitted     boolean     DEFAULT false;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS dietary_submitted_at  timestamptz;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS rsvp_status          text DEFAULT 'pending';
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS group_name           text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS plus_one             boolean NOT NULL DEFAULT false;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS plus_one_name        text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS seat                 text;
ALTER TABLE event_guests ADD COLUMN IF NOT EXISTS notes                text;

ALTER TABLE event_guests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own event guests" ON event_guests;
CREATE POLICY "users manage own event guests" ON event_guests FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.user_id = auth.uid()));

-- ── get_my_events() ───────────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_my_events();
CREATE FUNCTION get_my_events()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(e ORDER BY e.event_date ASC NULLS LAST, e.created_at DESC), '[]'::jsonb)
    FROM (
      SELECT id, name, event_type, event_date, venue_name, notes, layout, created_at,
             (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = events.id)::int AS guest_count
      FROM events WHERE user_id = auth.uid()
    ) e
  );
END; $$;
GRANT EXECUTE ON FUNCTION get_my_events() TO authenticated;

-- ── upsert_event(...) ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS upsert_event(uuid, text, text, date, text, text, jsonb);
CREATE FUNCTION upsert_event(
  p_id         uuid    DEFAULT NULL,
  p_name       text    DEFAULT NULL,
  p_event_type text    DEFAULT NULL,
  p_event_date date    DEFAULT NULL,
  p_venue_name text    DEFAULT NULL,
  p_notes      text    DEFAULT NULL,
  p_layout     jsonb   DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_id IS NOT NULL THEN
    UPDATE events SET
      name       = COALESCE(p_name, name),
      event_type = COALESCE(p_event_type, event_type),
      event_date = COALESCE(p_event_date, event_date),
      venue_name = COALESCE(p_venue_name, venue_name),
      notes      = COALESCE(p_notes, notes),
      layout     = CASE WHEN p_layout IS NOT NULL THEN p_layout ELSE layout END,
      updated_at = NOW()
    WHERE id = p_id AND user_id = auth.uid()
    RETURNING id INTO v_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;
  ELSE
    INSERT INTO events (user_id, name, event_type, event_date, venue_name, notes, layout)
    VALUES (auth.uid(), p_name, p_event_type, p_event_date, p_venue_name, p_notes,
            COALESCE(p_layout, '{"tables":[]}'::jsonb))
    RETURNING id INTO v_id;
  END IF;
  RETURN (SELECT row_to_json(e)::jsonb FROM events e WHERE id = v_id);
END; $$;
GRANT EXECUTE ON FUNCTION upsert_event(uuid, text, text, date, text, text, jsonb) TO authenticated;

-- ── delete_event(p_id) ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS delete_event(uuid);
CREATE FUNCTION delete_event(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  DELETE FROM events WHERE id = p_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION delete_event(uuid) TO authenticated;

-- ── get_event_guests(p_event_id) ──────────────────────────────────────
DROP FUNCTION IF EXISTS get_event_guests(uuid);
CREATE FUNCTION get_event_guests(p_event_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Event not found';
  END IF;
  RETURN (
    SELECT COALESCE(jsonb_agg(g ORDER BY g.created_at ASC), '[]'::jsonb)
    FROM (
      SELECT id, event_id, name, dietary_requirements, rsvp_status,
             group_name, plus_one, plus_one_name, seat, notes, created_at
      FROM event_guests WHERE event_id = p_event_id
    ) g
  );
END; $$;
GRANT EXECUTE ON FUNCTION get_event_guests(uuid) TO authenticated;

-- ── upsert_guest(...) ─────────────────────────────────────────────────
-- Drop both old and new signatures to handle upgrades
DROP FUNCTION IF EXISTS upsert_guest(uuid, uuid, text, text, text, text, boolean, text, text);
DROP FUNCTION IF EXISTS upsert_guest(uuid, uuid, text, jsonb, text, text, boolean, text, text);
CREATE FUNCTION upsert_guest(
  p_id                   uuid    DEFAULT NULL,
  p_event_id             uuid    DEFAULT NULL,
  p_name                 text    DEFAULT NULL,
  p_dietary_requirements jsonb   DEFAULT NULL,
  p_rsvp_status          text    DEFAULT 'pending',
  p_group_name           text    DEFAULT NULL,
  p_plus_one             boolean DEFAULT false,
  p_plus_one_name        text    DEFAULT NULL,
  p_notes                text    DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM events WHERE id = p_event_id AND user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Event not found';
  END IF;
  IF p_id IS NOT NULL THEN
    UPDATE event_guests SET
      name                 = COALESCE(p_name, name),
      dietary_requirements = p_dietary_requirements,
      rsvp_status          = COALESCE(p_rsvp_status, rsvp_status),
      group_name           = p_group_name,
      plus_one             = COALESCE(p_plus_one, plus_one),
      plus_one_name        = p_plus_one_name,
      notes                = p_notes
    WHERE id = p_id AND event_id = p_event_id
    RETURNING id INTO v_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Guest not found'; END IF;
  ELSE
    INSERT INTO event_guests (event_id, name, dietary_requirements, rsvp_status,
                              group_name, plus_one, plus_one_name, notes)
    VALUES (p_event_id, p_name, p_dietary_requirements, p_rsvp_status,
            p_group_name, COALESCE(p_plus_one, false), p_plus_one_name, p_notes)
    RETURNING id INTO v_id;
  END IF;
  RETURN (SELECT row_to_json(g)::jsonb FROM event_guests g WHERE id = v_id);
END; $$;
GRANT EXECUTE ON FUNCTION upsert_guest(uuid, uuid, text, jsonb, text, text, boolean, text, text) TO authenticated;

-- ── delete_guest(p_id) ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS delete_guest(uuid);
CREATE FUNCTION delete_guest(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  DELETE FROM event_guests g
  USING events e
  WHERE g.id = p_id AND g.event_id = e.id AND e.user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Guest not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION delete_guest(uuid) TO authenticated;

-- ── assign_seat(p_guest_id, p_seat) ──────────────────────────────────
-- p_seat NULL = unassign
DROP FUNCTION IF EXISTS assign_seat(uuid, text);
CREATE FUNCTION assign_seat(p_guest_id uuid, p_seat text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE event_guests g SET seat = p_seat
  FROM events e
  WHERE g.id = p_guest_id AND g.event_id = e.id AND e.user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Guest not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION assign_seat(uuid, text) TO authenticated;

-- ── save_event_layout(p_id, p_layout) ────────────────────────────────
DROP FUNCTION IF EXISTS save_event_layout(uuid, jsonb);
CREATE FUNCTION save_event_layout(p_id uuid, p_layout jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE events SET layout = p_layout, updated_at = NOW()
  WHERE id = p_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION save_event_layout(uuid, jsonb) TO authenticated;


-- Revoke public execute on all table planner functions
REVOKE ALL ON FUNCTION get_my_events() FROM PUBLIC;
REVOKE ALL ON FUNCTION upsert_event(uuid, text, text, date, text, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION delete_event(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_event_guests(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION upsert_guest(uuid, uuid, text, jsonb, text, text, boolean, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION delete_guest(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION assign_seat(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION save_event_layout(uuid, jsonb) FROM PUBLIC;

SELECT 'Table planner ready — ' ||
  (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN
   ('get_my_events','upsert_event','delete_event','get_event_guests',
    'upsert_guest','delete_guest','assign_seat','save_event_layout'))
  || '/8 RPCs installed' AS status;

SELECT pg_notify('pgrst', 'reload schema');


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/setup-collections.sql  [feature] owner=collections
-- ──────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — Collections + Quick Edit + Public Profile
-- Run in Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── COLLECTIONS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.collections (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text DEFAULT '',
  emoji       text DEFAULT '📁',
  is_public   boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own collections" ON public.collections;
CREATE POLICY "Users manage own collections"
  ON public.collections FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Public collections readable" ON public.collections;
CREATE POLICY "Public collections readable"
  ON public.collections FOR SELECT TO anon, authenticated
  USING (is_public = true);

-- ── COLLECTION RECIPES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.collection_recipes (
  collection_id uuid REFERENCES public.collections(id) ON DELETE CASCADE,
  recipe_id     uuid REFERENCES public.submitted_recipes(id) ON DELETE CASCADE,
  added_at      timestamptz DEFAULT now(),
  PRIMARY KEY (collection_id, recipe_id)
);
ALTER TABLE public.collection_recipes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own collection recipes" ON public.collection_recipes;
CREATE POLICY "Users manage own collection recipes"
  ON public.collection_recipes FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.collections c WHERE c.id = collection_id AND c.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.collections c WHERE c.id = collection_id AND c.user_id = auth.uid()));

-- ── COLLECTION RPCs ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_my_collections()
RETURNS TABLE (
  id uuid, name text, description text, emoji text,
  is_public boolean, recipe_count bigint, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT c.id, c.name, c.description, c.emoji, c.is_public,
           COUNT(cr.recipe_id)::bigint, c.created_at
    FROM public.collections c
    LEFT JOIN public.collection_recipes cr ON cr.collection_id = c.id
    WHERE c.user_id = auth.uid()
    GROUP BY c.id ORDER BY c.created_at DESC;
END; $$;
GRANT EXECUTE ON FUNCTION get_my_collections() TO authenticated;

CREATE OR REPLACE FUNCTION upsert_collection(
  p_id uuid DEFAULT NULL, p_name text DEFAULT '',
  p_description text DEFAULT '', p_emoji text DEFAULT '📁',
  p_is_public boolean DEFAULT false
)
RETURNS public.collections
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.collections;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.collections (user_id, name, description, emoji, is_public)
    VALUES (auth.uid(), p_name, p_description, p_emoji, p_is_public)
    RETURNING * INTO result;
  ELSE
    UPDATE public.collections SET name=p_name, description=p_description,
      emoji=p_emoji, is_public=p_is_public
    WHERE id=p_id AND user_id=auth.uid() RETURNING * INTO result;
  END IF;
  RETURN result;
END; $$;
GRANT EXECUTE ON FUNCTION upsert_collection(uuid,text,text,text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION delete_collection(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.collections WHERE id=p_id AND user_id=auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION delete_collection(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION add_to_collection(p_collection_id uuid, p_recipe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.collections WHERE id=p_collection_id AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  INSERT INTO public.collection_recipes (collection_id, recipe_id) VALUES (p_collection_id, p_recipe_id)
  ON CONFLICT DO NOTHING;
END; $$;
GRANT EXECUTE ON FUNCTION add_to_collection(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION remove_from_collection(p_collection_id uuid, p_recipe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.collection_recipes
  WHERE collection_id=p_collection_id AND recipe_id=p_recipe_id
    AND EXISTS (SELECT 1 FROM public.collections WHERE id=p_collection_id AND user_id=auth.uid());
END; $$;
GRANT EXECUTE ON FUNCTION remove_from_collection(uuid,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION get_collection_recipes(p_collection_id uuid)
RETURNS TABLE (
  id uuid, recipe_name text, category text, origin_country text,
  image_url text, dietary_tags text[], status text, added_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.collections c WHERE c.id = p_collection_id
    AND (c.user_id = auth.uid() OR c.is_public = true)
  ) THEN RAISE EXCEPTION 'not_found'; END IF;
  RETURN QUERY
    SELECT sr.id, sr.recipe_name, sr.category, sr.origin_country,
           sr.image_url, sr.dietary_tags, sr.status, cr.added_at
    FROM public.collection_recipes cr
    JOIN public.submitted_recipes sr ON sr.id=cr.recipe_id
    WHERE cr.collection_id=p_collection_id
    ORDER BY cr.added_at DESC;
END; $$;
GRANT EXECUTE ON FUNCTION get_collection_recipes(uuid) TO authenticated, anon;

-- Check if recipe is in any of user's collections
CREATE OR REPLACE FUNCTION get_recipe_collections(p_recipe_id uuid)
RETURNS TABLE (id uuid, name text, emoji text, has_recipe boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT c.id, c.name, c.emoji,
           EXISTS(SELECT 1 FROM public.collection_recipes cr WHERE cr.collection_id=c.id AND cr.recipe_id=p_recipe_id)
    FROM public.collections c WHERE c.user_id=auth.uid() ORDER BY c.name;
END; $$;
GRANT EXECUTE ON FUNCTION get_recipe_collections(uuid) TO authenticated;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/setup-family-profiles.sql  [feature] owner=family-profiles
-- ──────────────────────────────────────────────────────────────────

-- ── Security note: Guest Dietary Cards use UUID bearer tokens ───────────
-- get_guest_card(uuid) and submit_guest_dietary(uuid, text) are callable
-- by anon. The guest ID acts as a bearer token. This is intentional for
-- the guest dietary card sharing workflow. Tokens have no server-side expiry.
-- Mitigations: UUIDs are 128-bit random (not guessable), and the data 
-- exposed (dietary requirements) is not sensitive PII. If expiry is needed,
-- add an expires_at column to family_profiles and check it in the function.
-- ─────────────────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — Family Profiles + Guest Dietary Cards
-- Run in Supabase → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── FAMILY PROFILES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.family_profiles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name             text NOT NULL,
  relationship     text DEFAULT 'guest',
    -- self | partner | child | toddler | baby | elderly | regular_guest | other
  age_group        text DEFAULT 'adult',
    -- adult | child | toddler | baby | elderly
  allergies        jsonb  NOT NULL DEFAULT '[]',
  spice_preference text DEFAULT 'medium',
    -- none | mild | medium | hot | very_hot
  dietary_needs    jsonb  NOT NULL DEFAULT '[]',
  health_conditions text[] DEFAULT '{}',
  notes            text,
  created_at       timestamptz DEFAULT now()
);
ALTER TABLE public.family_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own family profiles" ON public.family_profiles;
CREATE POLICY "Users manage own family profiles"
  ON public.family_profiles FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── GUEST DIETARY CARD TRACKING ──────────────────────────────────
-- Add submitted flag to existing guests table
-- dietary_submitted columns are in table_planner.sql

-- ── FAMILY PROFILE RPCs ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.upsert_family_profile(uuid,text,text,text,jsonb,text,jsonb,text[],text);
CREATE OR REPLACE FUNCTION upsert_family_profile(
  p_id               uuid    DEFAULT NULL,
  p_name             text    DEFAULT '',
  p_relationship     text    DEFAULT 'guest',
  p_age_group        text    DEFAULT 'adult',
  p_allergies        jsonb   DEFAULT '[]',
  p_spice_preference text    DEFAULT 'medium',
  p_dietary_needs    jsonb   DEFAULT '[]',
  p_health_conditions text[] DEFAULT '{}',
  p_notes            text    DEFAULT ''
)
RETURNS public.family_profiles
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.family_profiles;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.family_profiles
      (user_id, name, relationship, age_group, allergies, spice_preference, dietary_needs, health_conditions, notes)
    VALUES
      (auth.uid(), p_name, p_relationship, p_age_group, p_allergies, p_spice_preference, p_dietary_needs, p_health_conditions, p_notes)
    RETURNING * INTO result;
  ELSE
    UPDATE public.family_profiles SET
      name=p_name, relationship=p_relationship, age_group=p_age_group,
      allergies=p_allergies, spice_preference=p_spice_preference,
      dietary_needs=p_dietary_needs, health_conditions=p_health_conditions, notes=p_notes
    WHERE id=p_id AND user_id=auth.uid()
    RETURNING * INTO result;
  END IF;
  RETURN result;
END; $$;
GRANT EXECUTE ON FUNCTION upsert_family_profile(uuid,text,text,text,jsonb,text,jsonb,text[],text) TO authenticated;

CREATE OR REPLACE FUNCTION delete_family_profile(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM public.family_profiles WHERE id=p_id AND user_id=auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION delete_family_profile(uuid) TO authenticated;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/notification_rpcs.sql  [feature] owner=notifications
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- Notification RPCs — The Culinary Journal
-- Written against the actual notifications table schema:
--   id, user_id, type, recipe_id, recipe_name, message, read, created_at
-- Does NOT alter the table — only creates/replaces functions
-- ══════════════════════════════════════════════════════════════════════

-- ── send_notification — ADMIN ONLY ────────────────────────────────────
-- Inserts a notification for any user — admin only
DROP FUNCTION IF EXISTS send_notification(uuid, text, uuid, text, text);
CREATE FUNCTION send_notification(
  p_user_id    uuid,
  p_type       text,
  p_recipe_id  uuid    DEFAULT NULL,
  p_recipe_name text   DEFAULT NULL,
  p_message    text    DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  INSERT INTO notifications (user_id, type, recipe_id, recipe_name, message)
  VALUES (p_user_id, p_type, p_recipe_id, p_recipe_name, p_message);
END;
$$;

SELECT 'Notification RPCs ready' AS status;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/recipe_management.sql  [feature] owner=recipe-admin
-- ──────────────────────────────────────────────────────────────────

-- ── recipe_drafts table ──────────────────────────────────────────────
-- Stores auto-saved and named drafts from submit-recipe.html
CREATE TABLE IF NOT EXISTS public.recipe_drafts (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_name text,
  draft_data  jsonb       NOT NULL DEFAULT '{}',
  local_key   text,
  updated_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE public.recipe_drafts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own drafts" ON public.recipe_drafts;
CREATE POLICY "Users manage own drafts" ON public.recipe_drafts
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS recipe_drafts_updated_at ON public.recipe_drafts;
CREATE TRIGGER recipe_drafts_updated_at
  BEFORE UPDATE ON public.recipe_drafts
  FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ── Recipe Management SQL ─────────────────────────────────────────

-- ── 1. Add columns to submitted_recipes ──────────────────────────
ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS is_featured            BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS featured_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_recipe_of_week      BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recipe_of_week_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS recipe_of_week_expires TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS native_title        TEXT,
  ADD COLUMN IF NOT EXISTS introduction        TEXT,
  ADD COLUMN IF NOT EXISTS cooking_notes       TEXT,
  ADD COLUMN IF NOT EXISTS photo_url           TEXT;

-- ── 2. Collections table ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recipe_collections (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  description TEXT,
  recipe_ids  UUID[] NOT NULL DEFAULT '{}',
  published   BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.recipe_collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.recipe_collections;
CREATE POLICY "Admin full access" ON public.recipe_collections FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 3. Enhanced admin_get_recipes ────────────────────────────────
-- ── 4. Get full recipe detail ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipe_detail(uuid);
CREATE OR REPLACE FUNCTION public.admin_get_recipe_detail(p_id UUID)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT row_to_json(t) INTO result FROM (
    SELECT r.*, p.username, p.full_name, p.avatar_url as submitter_avatar
    FROM public.submitted_recipes r
    LEFT JOIN public.profiles p ON p.id = r.user_id
    WHERE r.id = p_id
  ) t;
  RETURN result;
END;
$$;

-- ── 5. Review recipe (approve/reject/reset) ───────────────────────
-- ── 6. Edit recipe fields before approving ────────────────────────
DROP FUNCTION IF EXISTS public.admin_edit_recipe(uuid, text, text, text, text, text, text, integer);
CREATE OR REPLACE FUNCTION public.admin_edit_recipe(
  p_id UUID, p_recipe_name TEXT DEFAULT NULL, p_category TEXT DEFAULT NULL,
  p_spice_level TEXT DEFAULT NULL, p_native_title TEXT DEFAULT NULL,
  p_introduction TEXT DEFAULT NULL, p_cooking_notes TEXT DEFAULT NULL,
  p_servings INT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes SET
    recipe_name   = COALESCE(p_recipe_name,   recipe_name),
    category      = COALESCE(p_category,       category),
    spice_level   = COALESCE(p_spice_level,    spice_level),
    native_title  = COALESCE(p_native_title,   native_title),
    introduction  = COALESCE(p_introduction,   introduction),
    cooking_notes = COALESCE(p_cooking_notes,  cooking_notes),
    servings      = COALESCE(p_servings,       servings)
  WHERE id = p_id;
END;
$$;

-- ── 7. Feature/unfeature recipe ───────────────────────────────────
DROP FUNCTION IF EXISTS admin_feature_recipe(UUID, BOOLEAN);
CREATE OR REPLACE FUNCTION public.admin_feature_recipe(p_id UUID, p_featured BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes SET is_featured = p_featured,
    featured_at = CASE WHEN p_featured THEN now() ELSE NULL END
  WHERE id = p_id;
END;
$$;

-- ── 8. Set recipe of the week ─────────────────────────────────────
DROP FUNCTION IF EXISTS admin_set_recipe_of_week(UUID);
CREATE OR REPLACE FUNCTION public.admin_set_recipe_of_week(p_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  -- Clear existing recipe of the week
  UPDATE public.submitted_recipes SET is_recipe_of_week = false, recipe_of_week_expires = NULL
  WHERE is_recipe_of_week = true;
  -- Set new one, expires in 7 days
  UPDATE public.submitted_recipes SET
    is_recipe_of_week = true,
    recipe_of_week_at = now(),
    recipe_of_week_expires = now() + interval '7 days'
  WHERE id = p_id;
END;
$$;

-- ── 9. Get recipe stats ───────────────────────────────────────────
-- ── 10. Collections CRUD ──────────────────────────────────────────
DROP FUNCTION IF EXISTS admin_get_collections();
CREATE OR REPLACE FUNCTION public.admin_get_collections()
RETURNS SETOF public.recipe_collections
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.recipe_collections ORDER BY updated_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.admin_save_collection(bigint, text, text, uuid[], boolean);
CREATE OR REPLACE FUNCTION public.admin_save_collection(
  p_id BIGINT DEFAULT NULL, p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL, p_recipe_ids UUID[] DEFAULT '{}',
  p_published BOOLEAN DEFAULT false
)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id BIGINT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_id IS NULL OR p_id = 0 THEN
    INSERT INTO public.recipe_collections (name, description, recipe_ids, published)
    VALUES (p_name, p_description, p_recipe_ids, p_published)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_collections SET
      name = COALESCE(p_name, name),
      description = p_description,
      recipe_ids = p_recipe_ids,
      published = p_published,
      updated_at = now()
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS admin_delete_collection(BIGINT);
CREATE OR REPLACE FUNCTION public.admin_delete_collection(p_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.recipe_collections WHERE id = p_id;
END;
$$;

-- ── Grants ────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.admin_get_recipe_detail(uuid)                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_edit_recipe(uuid,text,text,text,text,text,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_feature_recipe(uuid,boolean)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_recipe_of_week(uuid)                       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_collections()                              TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_collection(bigint,text,text,uuid[],boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_collection(bigint)                      TO authenticated;
NOTIFY pgrst, 'reload schema';


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/user_management.sql  [feature] owner=user-admin
-- ──────────────────────────────────────────────────────────────────

-- ── User Management SQL ───────────────────────────────────────────
-- Run this entire block in Supabase SQL Editor

-- ── 1. Add columns to profiles table ────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS flagged              BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS deactivation_type    TEXT      CHECK (deactivation_type IN ('temporary','permanent')),
  ADD COLUMN IF NOT EXISTS deactivation_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deactivation_reason  TEXT,
  ADD COLUMN IF NOT EXISTS plan                 TEXT      NOT NULL DEFAULT 'free' CHECK (plan IN ('free','premium')),
  ADD COLUMN IF NOT EXISTS last_active_at       TIMESTAMPTZ;

-- ── 2. User badges table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_badges (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge       TEXT NOT NULL,
  awarded_by  TEXT,
  awarded_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, badge)
);
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_badges;
CREATE POLICY "Admin full access" ON public.user_badges FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 3. User internal notes table ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_notes (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  note        TEXT NOT NULL,
  created_by  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_notes;
CREATE POLICY "Admin full access" ON public.user_notes FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 4. User invites table ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_invites (
  id          BIGSERIAL PRIMARY KEY,
  email       TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'contributor' CHECK (role IN ('contributor','guest_chef')),
  message     TEXT,
  token       TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32),'hex'),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','expired')),
  invited_by  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '30 days'),
  accepted_at TIMESTAMPTZ
);
ALTER TABLE public.user_invites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_invites;
CREATE POLICY "Admin full access" ON public.user_invites FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 5. Reports table ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_reports (
  id              BIGSERIAL PRIMARY KEY,
  reporter_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reported_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  recipe_id       UUID,
  reason          TEXT NOT NULL,
  details         TEXT,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed','actioned')),
  reviewed_by     TEXT,
  reviewed_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_reports;
CREATE POLICY "Admin full access" ON public.user_reports FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 6. Recipe requests table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recipe_requests (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  request_text    TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','fulfilled','declined')),
  notes           TEXT,
  fulfilled_recipe_id UUID,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.recipe_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.recipe_requests;
CREATE POLICY "Admin full access" ON public.recipe_requests FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 7. User feedback table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_feedback (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  feedback    TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'general' CHECK (type IN ('general','recipe','bug','suggestion')),
  status      TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewed','actioned','dismissed')),
  recipe_id   UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_feedback ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.user_feedback;
CREATE POLICY "Admin full access" ON public.user_feedback FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ── 8. Get users (paginated, filtered) ───────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_users(text, text, int, int);
CREATE OR REPLACE FUNCTION public.admin_get_users(
  p_search  TEXT    DEFAULT NULL,
  p_status  TEXT    DEFAULT NULL,
  p_limit   INT     DEFAULT 50,
  p_offset  INT     DEFAULT 0
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_agg(row_to_json(t)) FROM (
    SELECT
      p.id, u.email, p.full_name, p.username, p.is_active, p.is_admin,
      p.theme_preference, p.created_at, p.avatar_url, p.flagged,
      p.deactivation_type, p.deactivation_expires_at, p.deactivation_reason, p.plan,
      CASE
        WHEN p.is_active = false AND p.deactivation_type = 'permanent' THEN 'Permanently Deactivated'
        WHEN p.is_active = false AND p.deactivation_type = 'temporary' THEN 'Temporarily Deactivated'
        WHEN p.is_active = false THEN 'Deactivated'
        WHEN p.flagged = true THEN 'Flagged'
        WHEN p.is_admin = true THEN 'Administrator'
        ELSE 'Active'
      END as account_status,
      COALESCE((SELECT COUNT(*) FROM public.submitted_recipes r WHERE r.user_id = p.id),0) as recipe_count,
      COALESCE((SELECT COUNT(*) FROM public.submitted_recipes r WHERE r.user_id = p.id AND r.status = 'approved'),0) as approved_count,
      COALESCE((SELECT json_agg(b.badge) FROM public.user_badges b WHERE b.user_id = p.id),'[]'::json) as badges
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE (
      p_search IS NULL OR p_search = '' OR
      p.full_name ILIKE '%'||p_search||'%' OR
      p.username  ILIKE '%'||p_search||'%' OR
      u.email     ILIKE '%'||p_search||'%'
    )
    AND (
      p_status IS NULL OR p_status = '' OR
      (p_status = 'active'      AND p.is_active = true  AND p.flagged = false AND p.is_admin = false) OR
      (p_status = 'admin'       AND p.is_admin  = true) OR
      (p_status = 'flagged'     AND p.flagged   = true) OR
      (p_status = 'deactivated' AND p.is_active = false)
    )
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t INTO result;
  RETURN COALESCE(result, '[]'::json);
END;
$$;

-- ── 9. Count users ────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_count_users(text, text);
CREATE OR REPLACE FUNCTION public.admin_count_users(
  p_search TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count bigint;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_count FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
  WHERE (
    p_search IS NULL OR p_search = '' OR
    p.full_name ILIKE '%'||p_search||'%' OR
    p.username  ILIKE '%'||p_search||'%' OR
    u.email     ILIKE '%'||p_search||'%'
  )
  AND (
    p_status IS NULL OR p_status = '' OR
    (p_status = 'active'      AND p.is_active = true  AND p.flagged = false AND p.is_admin = false) OR
    (p_status = 'admin'       AND p.is_admin  = true) OR
    (p_status = 'flagged'     AND p.flagged   = true) OR
    (p_status = 'deactivated' AND p.is_active = false)
  );
  RETURN v_count;
END;
$$;

-- ── 10. Get full user detail ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_user_detail(uuid);
CREATE OR REPLACE FUNCTION public.admin_get_user_detail(p_user_id UUID)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'profile', (
      SELECT row_to_json(t) FROM (
        SELECT p.*,
          CASE
            WHEN p.is_active = false AND p.deactivation_type = 'permanent' THEN 'Permanently Deactivated'
            WHEN p.is_active = false AND p.deactivation_type = 'temporary' THEN 'Temporarily Deactivated'
            WHEN p.is_active = false THEN 'Deactivated'
            WHEN p.flagged = true THEN 'Flagged'
            WHEN p.is_admin = true THEN 'Administrator'
            ELSE 'Active'
          END as account_status,
          COALESCE((SELECT json_agg(b.badge ORDER BY b.awarded_at) FROM public.user_badges b WHERE b.user_id = p.id), '[]'::json) as badges
        FROM public.profiles p WHERE p.id = p_user_id
      ) t
    ),
    'recipe_count',   (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id),
    'approved_count', (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id AND status = 'approved'),
    'rejected_count', (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id AND status = 'rejected'),
    'pending_count',  (SELECT COUNT(*)   FROM public.submitted_recipes WHERE user_id = p_user_id AND status = 'pending'),
    'recent_recipes', (SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
      SELECT recipe_name as title, status FROM public.submitted_recipes
      WHERE user_id = p_user_id ORDER BY submitted_at DESC LIMIT 10
    ) t),
    'notes', (SELECT COALESCE(json_agg(row_to_json(n) ORDER BY n.created_at DESC),'[]'::json)
              FROM public.user_notes n WHERE n.user_id = p_user_id)
  ) INTO result;
  RETURN result;
END;
$$;

-- ── 11. Deactivate user ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_deactivate_user(uuid, text, integer, text);
CREATE OR REPLACE FUNCTION public.admin_deactivate_user(
  p_user_id UUID, p_type TEXT, p_days INT DEFAULT NULL, p_reason TEXT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active              = false,
    deactivation_type      = p_type,
    deactivation_expires_at = CASE WHEN p_type = 'temporary' AND p_days IS NOT NULL THEN now() + (p_days || ' days')::interval ELSE NULL END,
    deactivation_reason    = p_reason
  WHERE id = p_user_id;
END;
$$;

-- ── 12. Reactivate user ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_reactivate_user(uuid);
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_user_id UUID)
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

-- ── 13. Award badge ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_award_badge(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_award_badge(p_user_id UUID, p_badge TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.user_badges (user_id, badge, awarded_by)
  VALUES (p_user_id, p_badge, (SELECT username FROM public.profiles WHERE id = auth.uid()))
  ON CONFLICT (user_id, badge) DO NOTHING;
END;
$$;

-- ── 14. Remove badge ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_remove_badge(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_remove_badge(p_user_id UUID, p_badge TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.user_badges WHERE user_id = p_user_id AND badge = p_badge;
END;
$$;

-- ── 15. Add internal note ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_add_user_note(uuid, text);
CREATE OR REPLACE FUNCTION public.admin_add_user_note(p_user_id UUID, p_note TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.user_notes (user_id, note, created_by)
  VALUES (p_user_id, p_note, (SELECT username FROM public.profiles WHERE id = auth.uid()));
END;
$$;

-- ── 16. Flag/unflag user ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_flag_user(uuid, boolean);
CREATE OR REPLACE FUNCTION public.admin_flag_user(p_user_id UUID, p_flagged BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET flagged = p_flagged WHERE id = p_user_id;
END;
$$;

-- ── 17. Set admin status ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_set_admin_status(uuid, boolean);
CREATE OR REPLACE FUNCTION public.admin_set_admin_status(p_user_id UUID, p_is_admin BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET is_admin = p_is_admin WHERE id = p_user_id;
END;
$$;

-- ── 18. Get invites ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_invites();
CREATE OR REPLACE FUNCTION public.admin_get_invites()
RETURNS SETOF public.user_invites
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  -- Auto-expire old invites
  UPDATE public.user_invites SET status = 'expired'
  WHERE status = 'pending' AND expires_at < now();
  RETURN QUERY SELECT * FROM public.user_invites ORDER BY created_at DESC;
END;
$$;

-- ── 19. Create invite ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_create_invite(text, text, text);
CREATE OR REPLACE FUNCTION public.admin_create_invite(
  p_email TEXT, p_role TEXT DEFAULT 'contributor', p_message TEXT DEFAULT NULL
)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_token TEXT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  v_token := encode(gen_random_bytes(32),'hex');
  INSERT INTO public.user_invites (email, role, message, token, invited_by)
  VALUES (p_email, p_role, p_message, v_token,
    (SELECT username FROM public.profiles WHERE id = auth.uid()));
  RETURN v_token;
END;
$$;

-- ── 20. Count pending users (for badge) ──────────────────────────
DROP FUNCTION IF EXISTS public.admin_count_pending_users();
CREATE OR REPLACE FUNCTION public.admin_count_pending_users()
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count bigint;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_count FROM public.profiles WHERE is_active = false;
  RETURN v_count;
END;
$$;

-- ── 21. User analytics ────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_user_analytics();
CREATE OR REPLACE FUNCTION public.admin_get_user_analytics()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'total',         (SELECT COUNT(*) FROM public.profiles),
    'active',        (SELECT COUNT(*) FROM public.profiles WHERE is_active = true AND flagged = false),
    'deactivated',   (SELECT COUNT(*) FROM public.profiles WHERE is_active = false),
    'flagged',       (SELECT COUNT(*) FROM public.profiles WHERE flagged = true),
    'admins',        (SELECT COUNT(*) FROM public.profiles WHERE is_admin = true),
    'new_this_week', (SELECT COUNT(*) FROM public.profiles WHERE created_at > now() - interval '7 days'),
    'new_this_month',(SELECT COUNT(*) FROM public.profiles WHERE created_at > now() - interval '30 days'),
    'top_contributors', (
      SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
        SELECT p.full_name, p.username,
          COUNT(r.id) as recipe_count
        FROM public.profiles p
        JOIN public.submitted_recipes r ON r.user_id = p.id AND r.status = 'approved'
        GROUP BY p.id, p.full_name, p.username
        ORDER BY recipe_count DESC LIMIT 10
      ) t
    ),
    'growth', (
      SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
        SELECT TO_CHAR(DATE_TRUNC('month', created_at), 'Mon YY') as month,
               COUNT(*) as count
        FROM public.profiles
        WHERE created_at > now() - interval '6 months'
        GROUP BY DATE_TRUNC('month', created_at)
        ORDER BY DATE_TRUNC('month', created_at)
      ) t
    )
  ) INTO result;
  RETURN result;
END;
$$;

-- ── 22. Get reports ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_reports(text, int, int);
CREATE OR REPLACE FUNCTION public.admin_get_reports(
  p_status TEXT DEFAULT NULL, p_limit INT DEFAULT 100, p_offset INT DEFAULT 0
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
    SELECT r.*,
      rep.username as reporter_username, rep.full_name as reporter_name,
      rep2.username as reported_username, rep2.full_name as reported_name
    FROM public.user_reports r
    LEFT JOIN public.profiles rep  ON rep.id  = r.reporter_id
    LEFT JOIN public.profiles rep2 ON rep2.id = r.reported_user_id
    WHERE (p_status IS NULL OR r.status = p_status)
    ORDER BY r.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t INTO result;
  RETURN result;
END;
$$;

-- ── 23. Update report status ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_report(bigint, text);
CREATE OR REPLACE FUNCTION public.admin_update_report(
  p_id BIGINT, p_status TEXT
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.user_reports SET
    status = p_status, reviewed_at = now(),
    reviewed_by = (SELECT username FROM public.profiles WHERE id = auth.uid())
  WHERE id = p_id;
END;
$$;

-- ── 24. Get recipe requests ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipe_requests(text);
CREATE OR REPLACE FUNCTION public.admin_get_recipe_requests(
  p_status TEXT DEFAULT NULL
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
    SELECT rr.*, p.username, p.full_name
    FROM public.recipe_requests rr
    LEFT JOIN public.profiles p ON p.id = rr.user_id
    WHERE (p_status IS NULL OR rr.status = p_status)
    ORDER BY rr.created_at DESC
  ) t INTO result;
  RETURN result;
END;
$$;

-- ── 25. Update recipe request ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_recipe_request(bigint, text, text);
CREATE OR REPLACE FUNCTION public.admin_update_recipe_request(
  p_id BIGINT, p_status TEXT, p_notes TEXT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_requests SET status = p_status, notes = p_notes, updated_at = now()
  WHERE id = p_id;
END;
$$;

-- ── 26. Get feedback ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_feedback(text);
CREATE OR REPLACE FUNCTION public.admin_get_feedback(
  p_status TEXT DEFAULT NULL
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COALESCE(json_agg(row_to_json(t)),'[]'::json) FROM (
    SELECT f.*, p.username, p.full_name
    FROM public.user_feedback f
    LEFT JOIN public.profiles p ON p.id = f.user_id
    WHERE (p_status IS NULL OR f.status = p_status)
    ORDER BY f.created_at DESC
  ) t INTO result;
  RETURN result;
END;
$$;

-- ── 27. Update feedback ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_update_feedback(bigint, text);
CREATE OR REPLACE FUNCTION public.admin_update_feedback(
  p_id BIGINT, p_status TEXT
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.user_feedback SET status = p_status WHERE id = p_id;
END;
$$;

-- ── Grant all ─────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.admin_get_users(text,text,integer,integer)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_count_users(text,text)                         TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_user_detail(uuid)                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_user(uuid,text,integer,text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_user(uuid)                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_award_badge(uuid,text)                         TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_badge(uuid,text)                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_user_note(uuid,text)                       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_flag_user(uuid,boolean)                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_admin_status(uuid,boolean)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_invites()                                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_invite(text,text,text)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_count_pending_users()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_user_analytics()                           TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_reports(text,integer,integer)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_report(bigint,text)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_recipe_requests(text)                      TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_recipe_request(bigint,text,text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_feedback(text)                             TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_feedback(bigint,text)                   TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── update_avatar_url — called from profile.html ──────────────────
DROP FUNCTION IF EXISTS public.update_avatar_url(text);
CREATE FUNCTION public.update_avatar_url(p_url text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE profiles SET avatar_url = p_url WHERE id = auth.uid();
END; $$;
REVOKE ALL ON FUNCTION public.update_avatar_url(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.update_avatar_url(text) TO authenticated;
SELECT pg_notify('pgrst', 'reload schema'); -- reload after update_avatar_url


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/recipe_notes.sql  [feature] owner=recipe-notes
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- Recipe Notes — personal notes + public tip submissions
-- ══════════════════════════════════════════════════════════════════════

-- Personal notes: one per user per recipe, private
CREATE TABLE IF NOT EXISTS public.recipe_personal_notes (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id  uuid        NOT NULL REFERENCES submitted_recipes(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note       text        NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (recipe_id, user_id)
);
ALTER TABLE public.recipe_personal_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own personal notes" ON public.recipe_personal_notes;
CREATE POLICY "users manage own personal notes" ON public.recipe_personal_notes
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Public note submissions: submitted by users, reviewed by admin
CREATE TABLE IF NOT EXISTS public.recipe_public_notes (
  id         bigserial   PRIMARY KEY,
  recipe_id  uuid        NOT NULL REFERENCES submitted_recipes(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note       text        NOT NULL,
  status     text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_at timestamptz,
  reviewer_id uuid       REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE public.recipe_public_notes ENABLE ROW LEVEL SECURITY;
-- Users can insert their own
DROP POLICY IF EXISTS "users submit public notes" ON public.recipe_public_notes;
CREATE POLICY "users submit public notes" ON public.recipe_public_notes
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
-- Users can read their own
DROP POLICY IF EXISTS "users read own public notes" ON public.recipe_public_notes;
CREATE POLICY "users read own public notes" ON public.recipe_public_notes
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR (status = 'approved'));
-- Admin manages all
DROP POLICY IF EXISTS "admin manages public notes" ON public.recipe_public_notes;
CREATE POLICY "admin manages public notes" ON public.recipe_public_notes
  FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Get personal note for a recipe
DROP FUNCTION IF EXISTS public.get_my_recipe_note(uuid);
CREATE FUNCTION public.get_my_recipe_note(p_recipe_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN NULL; END IF;
  RETURN (SELECT note FROM recipe_personal_notes
          WHERE recipe_id = p_recipe_id AND user_id = auth.uid());
END; $$;
REVOKE ALL ON FUNCTION public.get_my_recipe_note(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_my_recipe_note(uuid) TO authenticated;

-- Admin: get pending public notes
DROP FUNCTION IF EXISTS public.admin_get_pending_notes();
CREATE FUNCTION public.admin_get_pending_notes()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(n ORDER BY n.created_at DESC)
     FROM (
       SELECT pn.id, pn.recipe_id, pn.note, pn.status, pn.created_at,
              sr.recipe_name, p.username AS submitted_by
       FROM recipe_public_notes pn
       JOIN submitted_recipes sr ON sr.id = pn.recipe_id
       JOIN profiles p ON p.id = pn.user_id
       WHERE pn.status = 'pending'
     ) n),
    '[]'::jsonb
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_pending_notes() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_pending_notes() TO authenticated;

-- Admin: approve or reject a public note
DROP FUNCTION IF EXISTS public.admin_review_note(bigint, text);
CREATE FUNCTION public.admin_review_note(p_id bigint, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE recipe_public_notes
  SET status = p_status, reviewed_at = NOW(), reviewer_id = auth.uid()
  WHERE id = p_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_review_note(bigint, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_review_note(bigint, text) TO authenticated;

SELECT 'Recipe notes ready' AS status;

SELECT pg_notify('pgrst', 'reload schema');


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/grocery_list.sql  [feature] owner=grocery
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- Grocery List — The Culinary Journal
-- Single-row-per-user storage matching grocery.html data structure
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS grocery_lists (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  list_data  jsonb NOT NULL DEFAULT '{"recipes":[]}',
  checked    jsonb NOT NULL DEFAULT '[]',
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE grocery_lists ADD COLUMN IF NOT EXISTS list_data  jsonb NOT NULL DEFAULT '{"recipes":[]}';
ALTER TABLE grocery_lists ADD COLUMN IF NOT EXISTS checked    jsonb NOT NULL DEFAULT '[]';
ALTER TABLE grocery_lists ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT NOW();
ALTER TABLE grocery_lists ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own grocery list" ON grocery_lists;
CREATE POLICY "users manage own grocery list" ON grocery_lists
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── get_my_grocery_list() ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS get_my_grocery_list();
CREATE FUNCTION get_my_grocery_list()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_build_object('list_data', list_data, 'checked', checked, 'updated_at', updated_at)
     FROM grocery_lists WHERE user_id = auth.uid()),
    jsonb_build_object('list_data', '{"recipes":[]}'::jsonb, 'checked', '[]'::jsonb, 'updated_at', NOW())
  );
END; $$;
GRANT EXECUTE ON FUNCTION get_my_grocery_list() TO authenticated;

-- ── save_my_grocery_list(p_list_data, p_checked) ─────────────────────
DROP FUNCTION IF EXISTS save_my_grocery_list(jsonb, jsonb);
CREATE FUNCTION save_my_grocery_list(p_list_data jsonb, p_checked jsonb DEFAULT '[]')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  INSERT INTO grocery_lists (user_id, list_data, checked, updated_at)
  VALUES (auth.uid(), p_list_data, p_checked, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    list_data  = EXCLUDED.list_data,
    checked    = EXCLUDED.checked,
    updated_at = NOW();
END; $$;
GRANT EXECUTE ON FUNCTION save_my_grocery_list(jsonb, jsonb) TO authenticated;

SELECT 'Grocery list ready' AS status;

REVOKE ALL ON FUNCTION get_my_grocery_list() FROM PUBLIC;
REVOKE ALL ON FUNCTION save_my_grocery_list(jsonb, jsonb) FROM PUBLIC;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/pantry.sql  [feature] owner=pantry
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- Pantry — The Culinary Journal
-- Stores each user's pantry items as a jsonb array.
-- One row per user — upsert on save.
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.pantry (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  items      jsonb       NOT NULL DEFAULT '[]',
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.pantry ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own pantry" ON public.pantry;
CREATE POLICY "users manage own pantry" ON public.pantry
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Save pantry items (full replace)
DROP FUNCTION IF EXISTS public.save_my_pantry(jsonb);
CREATE FUNCTION public.save_my_pantry(p_items jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  INSERT INTO pantry (user_id, items, updated_at)
  VALUES (auth.uid(), p_items, NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET items = EXCLUDED.items, updated_at = NOW();
END; $$;
REVOKE ALL ON FUNCTION public.save_my_pantry(jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.save_my_pantry(jsonb) TO authenticated;

-- Get pantry items
DROP FUNCTION IF EXISTS public.get_my_pantry();
CREATE FUNCTION public.get_my_pantry()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN COALESCE(
    (SELECT items FROM pantry WHERE user_id = auth.uid()),
    '[]'::jsonb
  );
END; $$;
REVOKE ALL ON FUNCTION public.get_my_pantry() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_my_pantry() TO authenticated;

SELECT 'Pantry ready' AS status;

SELECT pg_notify('pgrst', 'reload schema');


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/meal_planner.sql  [feature] owner=meal-planner
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- Meal Planner — The Culinary Journal
-- Table/RPC shapes match meal-planner.html exactly:
--   family_profiles: id, user_id, name, relationship, dietary_needs (jsonb),
--                    allergies (jsonb), spice_preference, created_at
-- RPCs: get_approved_recipes(p_limit), get_my_family_profiles()
-- ══════════════════════════════════════════════════════════════════════

-- ── Family profiles table ─────────────────────────────────────────────
-- Columns match what the frontend reads: relationship, dietary_needs,
-- allergies, spice_preference (not age/avatar/dietary_requirements)
CREATE TABLE IF NOT EXISTS family_profiles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             text NOT NULL,
  relationship     text DEFAULT 'other',
  dietary_needs    jsonb NOT NULL DEFAULT '[]',
  allergies        jsonb NOT NULL DEFAULT '[]',
  spice_preference text DEFAULT 'medium',
  created_at       timestamptz NOT NULL DEFAULT NOW()
);
-- Guards for existing table missing columns
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS name             text;
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS relationship     text DEFAULT 'other';
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS dietary_needs    jsonb;
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS allergies        jsonb;
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS spice_preference text DEFAULT 'medium';
ALTER TABLE family_profiles ADD COLUMN IF NOT EXISTS created_at       timestamptz;
-- Drop any old default before changing column type, then convert and restore
ALTER TABLE family_profiles ALTER COLUMN dietary_needs DROP DEFAULT;
ALTER TABLE family_profiles ALTER COLUMN allergies     DROP DEFAULT;
ALTER TABLE family_profiles ALTER COLUMN dietary_needs TYPE jsonb
  USING COALESCE(to_jsonb(dietary_needs), '[]'::jsonb);
ALTER TABLE family_profiles ALTER COLUMN allergies TYPE jsonb
  USING COALESCE(to_jsonb(allergies), '[]'::jsonb);
ALTER TABLE family_profiles ALTER COLUMN dietary_needs SET DEFAULT '[]'::jsonb;
ALTER TABLE family_profiles ALTER COLUMN allergies     SET DEFAULT '[]'::jsonb;
-- Set defaults on existing null rows
UPDATE family_profiles SET dietary_needs = '[]'::jsonb WHERE dietary_needs IS NULL;
UPDATE family_profiles SET allergies     = '[]'::jsonb WHERE allergies     IS NULL;

ALTER TABLE family_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own family profiles" ON family_profiles;
CREATE POLICY "users manage own family profiles" ON family_profiles
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

SELECT 'Meal planner ready' AS status;

-- ── Meal plans table + RPCs ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.meal_plans (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_key   text        NOT NULL,
  plan_data  jsonb       NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, week_key)
);
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own meal plans" ON public.meal_plans;
CREATE POLICY "users manage own meal plans" ON public.meal_plans
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP FUNCTION IF EXISTS public.save_my_meal_plan(text, jsonb);
CREATE FUNCTION public.save_my_meal_plan(p_week_key text, p_plan_data jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  INSERT INTO meal_plans (user_id, week_key, plan_data, updated_at)
  VALUES (auth.uid(), p_week_key, p_plan_data, NOW())
  ON CONFLICT (user_id, week_key)
  DO UPDATE SET plan_data = EXCLUDED.plan_data, updated_at = NOW();
END; $$;
REVOKE ALL ON FUNCTION public.save_my_meal_plan(text, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.save_my_meal_plan(text, jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.get_my_meal_plan(text);
CREATE FUNCTION public.get_my_meal_plan(p_week_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN (
    SELECT plan_data FROM meal_plans
    WHERE user_id = auth.uid() AND week_key = p_week_key
  );
END; $$;
REVOKE ALL ON FUNCTION public.get_my_meal_plan(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_my_meal_plan(text) TO authenticated;

SELECT 'Meal planner persistence ready' AS status;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/library-profiles.sql  [feature] owner=library
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- The Library — Content Profile Tables
-- Five profile types: ingredient, spice, tool, cut, preservation
-- All admin-controlled with visibility and status flags.
-- ══════════════════════════════════════════════════════════════════════

-- ── Shared helper ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

-- ── 1. INGREDIENT PROFILES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ingredient_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  also_known_as     text,
  local_names       jsonb       DEFAULT '[]',
  category          text,
  subcategory       text,
  image_url         text,
  origin_story      text,
  history           text,
  flavour_profile   text,
  how_to_buy        text,
  how_to_store      text,
  how_to_prep       text,
  when_to_add       text,
  common_mistakes   text,
  nutrition_notes   text,
  allergen          text,
  vegan             boolean     DEFAULT false,
  vegetarian        boolean     DEFAULT false,
  substitutes       text,
  chefs_notes       text,
  recommended_brand text,
  seasonality       text,
  science_notes     text,
  cultural_use      text,
  baby_notes        text,
  pairings          text,
  preservation_notes text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS ingredient_profiles_updated_at ON public.ingredient_profiles;
CREATE TRIGGER ingredient_profiles_updated_at BEFORE UPDATE ON public.ingredient_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 2. SPICE PROFILES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.spice_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  also_known_as     text,
  local_names       jsonb       DEFAULT '[]',
  image_url         text,
  origin_story      text,
  history           text,
  flavour_wheel     text,
  heat_level        integer     CHECK (heat_level BETWEEN 0 AND 5),
  whole_vs_ground   text,
  how_to_toast      text,
  blends            text,
  when_to_add       text,
  science_notes     text,
  cultural_use      text,
  chefs_notes       text,
  recommended_brand text,
  pairings          text,
  substitutes       text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS spice_profiles_updated_at ON public.spice_profiles;
CREATE TRIGGER spice_profiles_updated_at BEFORE UPDATE ON public.spice_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 3. TOOL & APPLIANCE PROFILES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tool_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  also_known_as     text,
  tool_category     text,
  image_url         text,
  what_its_for      text,
  how_to_use        text,
  how_to_care       text,
  common_mistakes   text,
  what_to_look_for  text,
  price_range       text,
  recommended_brand text,
  chefs_notes       text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS tool_profiles_updated_at ON public.tool_profiles;
CREATE TRIGGER tool_profiles_updated_at BEFORE UPDATE ON public.tool_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 4. CUT PROFILES (Meat & Seafood) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cut_profiles (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                text        UNIQUE NOT NULL,
  name                text        NOT NULL,
  also_known_as       text,
  international_names jsonb       DEFAULT '[]',
  protein_type        text        CHECK (protein_type IN ('beef','lamb','pork','chicken','duck','fish','seafood','other')),
  image_url           text,
  location_on_animal  text,
  characteristics     text,
  how_to_clean        text,
  how_to_prep         text,
  best_cooking_methods text,
  chefs_notes         text,
  did_you_know        text,
  status              text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility          text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by          uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT NOW(),
  updated_at          timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS cut_profiles_updated_at ON public.cut_profiles;
CREATE TRIGGER cut_profiles_updated_at BEFORE UPDATE ON public.cut_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 5. PRESERVATION PROFILES ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.preservation_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  technique_type    text        CHECK (technique_type IN ('canning','fermenting','pickling','drying','smoking','freezing','curing','other')),
  image_url         text,
  what_it_is        text,
  history           text,
  best_for          text,
  equipment_needed  text,
  step_by_step      jsonb       DEFAULT '[]',
  safety_notes      text,
  shelf_life        text,
  chefs_notes       text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS preservation_profiles_updated_at ON public.preservation_profiles;
CREATE TRIGGER preservation_profiles_updated_at BEFORE UPDATE ON public.preservation_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── RLS for all five tables ────────────────────────────────────────────
DO $$ DECLARE t text;
BEGIN FOR t IN SELECT unnest(ARRAY['ingredient_profiles','spice_profiles','tool_profiles','cut_profiles','preservation_profiles'])
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "public reads published" ON public.%I', t);
    EXECUTE format('CREATE POLICY "public reads published" ON public.%I FOR SELECT TO anon, authenticated USING (status = ''published'' AND visibility = ''public'')', t);
    EXECUTE format('DROP POLICY IF EXISTS "members read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "members read" ON public.%I FOR SELECT TO authenticated USING (status = ''published'' AND visibility IN (''public'',''members''))', t);
    EXECUTE format('DROP POLICY IF EXISTS "admin manages all" ON public.%I', t);
    EXECUTE format('CREATE POLICY "admin manages all" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
  END LOOP;
END $$;

-- ── Public RPCs ────────────────────────────────────────────────────────
-- Get directory listing for any profile type
DROP FUNCTION IF EXISTS public.get_library_directory(text, text, int, int);
CREATE FUNCTION public.get_library_directory(
  p_type     text,
  p_search   text    DEFAULT NULL,
  p_limit    int     DEFAULT 24,
  p_offset   int     DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_sql text; v_result jsonb;
BEGIN
  v_sql := format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY p.name ASC), ''[]''::jsonb)
     FROM (
       SELECT id, slug, name, also_known_as, image_url, %s AS type_extra,
              status, visibility, created_at
       FROM %I
       WHERE status = ''published''
         AND ($1 IS NULL OR name ILIKE ''%%'' || $1 || ''%%'' OR also_known_as ILIKE ''%%'' || $1 || ''%%'')
       ORDER BY name LIMIT $2 OFFSET $3
     ) p',
    CASE p_type
      WHEN 'ingredient'   THEN 'category'
      WHEN 'spice'        THEN 'heat_level::text'
      WHEN 'tool'         THEN 'tool_category'
      WHEN 'cut'          THEN 'protein_type'
      WHEN 'preservation' THEN 'technique_type'
      ELSE '''''' END,
    p_type || '_profiles'
  );
  EXECUTE v_sql INTO v_result USING p_search, p_limit, p_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.get_library_directory(text,text,int,int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_library_directory(text,text,int,int) TO anon, authenticated;

-- Get single profile by slug
DROP FUNCTION IF EXISTS public.get_library_profile(text, text);
CREATE FUNCTION public.get_library_profile(p_type text, p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  EXECUTE format(
    'SELECT row_to_json(p)::jsonb FROM %I p WHERE slug = $1 AND status = ''published''',
    p_type || '_profiles'
  ) INTO v_result USING p_slug;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.get_library_profile(text,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_library_profile(text,text) TO anon, authenticated;

-- ── Admin RPCs ─────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int);
CREATE FUNCTION public.admin_get_library_profiles(
  p_type   text,
  p_status text    DEFAULT NULL,
  p_limit  int     DEFAULT 50,
  p_offset int     DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY p.updated_at DESC), ''[]''::jsonb)
     FROM (SELECT id, slug, name, image_url, status, visibility, updated_at
           FROM %I
           WHERE ($1 IS NULL OR status = $1)
           ORDER BY updated_at DESC LIMIT $2 OFFSET $3) p',
    p_type || '_profiles'
  ) INTO v_result USING p_status, p_limit, p_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profiles(text,text,int,int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_library_profiles(text,text,int,int) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_publish_library_profile(text, uuid, text, text);
CREATE FUNCTION public.admin_publish_library_profile(
  p_type       text,
  p_id         uuid,
  p_status     text DEFAULT 'published',
  p_visibility text DEFAULT 'public'
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  EXECUTE format('UPDATE %I SET status=$1, visibility=$2, updated_at=NOW() WHERE id=$3',
    p_type||'_profiles') USING p_status, p_visibility, p_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_library_profile(text, uuid);
CREATE FUNCTION public.admin_delete_library_profile(p_type text, p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  EXECUTE format('DELETE FROM %I WHERE id=$1', p_type||'_profiles') USING p_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_library_profile(text,uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_delete_library_profile(text,uuid) TO authenticated;

SELECT 'Library profiles ready' AS status;

-- ── Supabase Storage bucket for library images ──────────────────────
-- Run this in the Supabase SQL editor after enabling Storage in your project.
-- NOTE: The bucket itself must be created in the Supabase Dashboard →
--       Storage → New bucket → Name: library-images → Public: ON
-- These policies then restrict who can upload.

INSERT INTO storage.buckets (id, name, public)
VALUES ('library-images', 'library-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Admin uploads library images" ON storage.objects;
CREATE POLICY "Admin uploads library images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'library-images'
    AND is_admin()
  );

DROP POLICY IF EXISTS "Admin updates library images" ON storage.objects;
CREATE POLICY "Admin updates library images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'library-images' AND is_admin());

DROP POLICY IF EXISTS "Anyone reads library images" ON storage.objects;
CREATE POLICY "Anyone reads library images"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'library-images');

SELECT 'library-images storage bucket ready' AS status;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/library_rls.sql  [policy] owner=library
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- Library / submitted_recipes RLS
-- Ensures approved recipes are publicly readable
-- Unapproved recipes are never exposed to the public
-- ══════════════════════════════════════════════════════════════════════

-- Confirm RLS is enabled on submitted_recipes
ALTER TABLE submitted_recipes ENABLE ROW LEVEL SECURITY;

-- Public can read approved recipes only
DROP POLICY IF EXISTS "public reads approved recipes" ON submitted_recipes;
CREATE POLICY "public reads approved recipes"
  ON submitted_recipes FOR SELECT
  USING (status = 'approved' AND visibility = 'Public');

-- Authenticated users can read their own recipes regardless of status
DROP POLICY IF EXISTS "users read own recipes" ON submitted_recipes;
CREATE POLICY "users read own recipes"
  ON submitted_recipes FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Authenticated users can insert their own recipes
DROP POLICY IF EXISTS "users insert own recipes" ON submitted_recipes;
CREATE POLICY "users insert own recipes"
  ON submitted_recipes FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- Authenticated users can update their own pending recipes
DROP POLICY IF EXISTS "users update own pending recipes" ON submitted_recipes;
CREATE POLICY "users update own pending recipes"
  ON submitted_recipes FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND status = 'pending')
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- Admins can do everything
DROP POLICY IF EXISTS "admin manages all recipes" ON submitted_recipes;
CREATE POLICY "admin manages all recipes"
  ON submitted_recipes FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

SELECT 'submitted_recipes RLS in place — approved recipes public, others private' AS status;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/email_templates.sql  [feature] owner=email
-- ──────────────────────────────────────────────────────────────────

-- ── email_templates table ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.email_templates (
  key        text PRIMARY KEY,
  name       text,
  subject    text,
  body       text,
  updated_at timestamptz DEFAULT NOW()
);
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin manages email templates" ON public.email_templates;
CREATE POLICY "Admin manages email templates" ON public.email_templates
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "Anon cannot read email templates" ON public.email_templates;
CREATE POLICY "Anon cannot read email templates" ON public.email_templates
  FOR SELECT TO anon USING (false);

-- ══════════════════════════════════════════════════════════════════════
-- Email Templates — written against actual schema:
--   key (text, PK), name (text), subject (text), body (text), updated_at
-- Does NOT drop or alter the table — only inserts/updates templates
-- and creates the email_queue table + queue_email RPC
-- ══════════════════════════════════════════════════════════════════════

-- RLS on existing table
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages email templates" ON email_templates;
CREATE POLICY "admin manages email templates"
  ON email_templates FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- Insert/update templates using actual columns: key, name, subject, body
INSERT INTO email_templates (key, name, subject, body, updated_at) VALUES

('welcome',
 'Welcome',
 'Welcome to The Culinary Journal',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Welcome, {{name}} 🍳</h2><p>Your account is ready. <a href="https://www.theculinaryjournal.site/recipes.html">Explore Recipes →</a></p>',
 NOW()),

('recipe_approved',
 'Recipe Approved',
 'Your recipe has been published ✓',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Your recipe is live 🎉</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> has been published. <a href="{{recipe_url}}">View it →</a></p>',
 NOW()),

('recipe_rejected',
 'Recipe Not Approved',
 'Update on your recipe submission',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#e8e0d4">Recipe not approved</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> was not approved at this time.</p><p><strong>Reason:</strong> {{rejection_reason}}</p><p><a href="https://www.theculinaryjournal.site/draft-recipes.html">View your drafts →</a></p>',
 NOW()),

('account_deactivated',
 'Account Deactivated',
 'Your account has been deactivated',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#dc5050">Account Deactivated</h2><p>Hi {{name}}, your account has been deactivated.</p><p><strong>Reason:</strong> {{reason}}</p><p>To appeal, reply to this email.</p>',
 NOW()),

('request_fulfilled',
 'Recipe Request Fulfilled',
 'Your recipe request has been fulfilled ✓',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">Request fulfilled 🍽</h2><p>Hi {{name}}, the recipe you requested — <strong>{{recipe_name}}</strong> — is now live. <a href="{{recipe_url}}">View it →</a></p>',
 NOW())

ON CONFLICT (key) DO UPDATE SET
  name       = EXCLUDED.name,
  subject    = EXCLUDED.subject,
  body       = EXCLUDED.body,
  updated_at = NOW();

-- ── Email queue (no FK — avoids schema mismatch) ──────────────────────
-- Handle existing email_queue with old column name template_id
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_id')
  AND NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_key') THEN
    ALTER TABLE email_queue RENAME COLUMN template_id TO template_key;
    RAISE NOTICE 'Renamed email_queue.template_id to template_key';
  END IF;
  -- Edge case: email_queue exists but has neither column (broken half-created table)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'email_queue')
  AND NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_key')
  AND NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'email_queue' AND column_name = 'template_id') THEN
    ALTER TABLE email_queue ADD COLUMN template_key text NOT NULL DEFAULT '';
    RAISE NOTICE 'Added missing template_key column to existing email_queue table';
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS email_queue (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_key text NOT NULL,
  to_email     text NOT NULL,
  to_name      text,
  variables    jsonb NOT NULL DEFAULT '{}',
  status       text NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','sending','sent','failed')),
  attempts     integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT NOW(),
  sent_at      timestamptz
);

ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages email queue" ON email_queue;
CREATE POLICY "admin manages email queue"
  ON email_queue FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- ── queue_email RPC — admin only ──────────────────────────────────────
DROP FUNCTION IF EXISTS queue_email(text, text, text, jsonb);
CREATE FUNCTION queue_email(
  p_template_key text,
  p_to_email     text,
  p_to_name      text DEFAULT NULL,
  p_variables    jsonb DEFAULT '{}'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  INSERT INTO email_queue (template_key, to_email, to_name, variables)
  VALUES (p_template_key, p_to_email, p_to_name, p_variables)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.queue_email(text, text, text, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.queue_email(text, text, text, jsonb) TO authenticated;

SELECT 'Email system ready — ' || COUNT(*) || ' templates' AS status
FROM email_templates;

-- ── Add missing columns to email_queue ────────────────────────────────
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS status     text        NOT NULL DEFAULT 'pending';
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS sent_at    timestamptz;
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS error_msg  text;
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT NOW();
-- Enforce correct status constraint immediately — not deferred to end of file
ALTER TABLE public.email_queue DROP CONSTRAINT IF EXISTS email_queue_status_check;
ALTER TABLE public.email_queue ADD CONSTRAINT email_queue_status_check
  CHECK (status IN ('pending','sending','sent','failed'));

-- Index for efficient queue polling
CREATE INDEX IF NOT EXISTS idx_email_queue_status ON public.email_queue(status, created_at);

-- ── Email templates for all key events ────────────────────────────────
INSERT INTO email_templates (key, name, subject, body) VALUES

('recipe_approved',
 'Recipe Approved',
 'Your recipe has been published! 🎉',
 '<h2>Your recipe is live!</h2><p>Hi {{name}},</p><p><strong>{{recipe_name}}</strong> has been approved and is now published on The Culinary Journal.</p><p><a href="{{site_url}}/recipe-page.html?id={{recipe_id}}">View your recipe →</a></p>')

ON CONFLICT (key) DO NOTHING;

INSERT INTO email_templates (key, name, subject, body) VALUES

('recipe_rejected',
 'Recipe Not Approved',
 'Update on your recipe submission',
 '<h2>Recipe update</h2><p>Hi {{name}},</p><p>Your recipe <strong>{{recipe_name}}</strong> was not approved at this time.</p><p><em>{{reviewer_notes}}</em></p><p>You can edit and resubmit from your <a href="{{site_url}}/my-dashboard.html">dashboard</a>.</p>')

ON CONFLICT (key) DO NOTHING;

INSERT INTO email_templates (key, name, subject, body) VALUES

('note_approved',
 'Cooking Tip Approved',
 'Your cooking tip has been published',
 '<h2>Your tip is live!</h2><p>Hi {{name}},</p><p>Your cooking tip for <strong>{{recipe_name}}</strong> has been approved and is now visible to other members.</p>')

ON CONFLICT (key) DO NOTHING;

SELECT 'Email templates updated' AS status;

-- Status constraint enforced above, immediately after ADD COLUMN.

-- ── Add retry tracking columns ─────────────────────────────────────────
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS attempts        integer     NOT NULL DEFAULT 0;
ALTER TABLE public.email_queue ADD COLUMN IF NOT EXISTS last_attempt_at timestamptz;


SELECT pg_notify('pgrst', 'reload schema');


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/finance_tables.sql  [feature] owner=finance
-- ──────────────────────────────────────────────────────────────────

-- ── Finance Management Tables ────────────────────────────────────────────
-- Run in Supabase SQL Editor

-- Pricing configuration (stored in site_settings, but also as dedicated table)
-- We use site_settings for prices so admin can change them without SQL

INSERT INTO public.site_settings (key, value) VALUES
  ('price_premium_monthly',    '4.00'),
  ('price_premium_annual',     '40.00'),
  ('price_event_monthly',      '12.00'),
  ('price_event_annual',       '120.00'),
  ('currency_symbol',          '$'),
  ('currency_code',            'USD')
ON CONFLICT (key) DO NOTHING;

-- Member subscription log (manual upgrades + future Stripe webhooks write here)
CREATE TABLE IF NOT EXISTS public.member_subscriptions (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tier            TEXT NOT NULL CHECK (tier IN ('free','premium','event')),
  status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','cancelled','expired','trialing')),
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at      TIMESTAMPTZ,
  cancelled_at    TIMESTAMPTZ,
  source          TEXT DEFAULT 'manual' CHECK (source IN ('manual','stripe','promo')),
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.member_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin full access" ON public.member_subscriptions;
CREATE POLICY "Admin full access" ON public.member_subscriptions
  FOR ALL USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT, INSERT, UPDATE ON public.member_subscriptions TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.member_subscriptions_id_seq TO authenticated;

CREATE INDEX IF NOT EXISTS member_subscriptions_user_idx ON public.member_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS member_subscriptions_tier_idx ON public.member_subscriptions(tier, status);

-- RPC: admin get tier statistics
DROP FUNCTION IF EXISTS admin_get_tier_stats();
DROP FUNCTION IF EXISTS public.admin_get_tier_stats();
CREATE OR REPLACE FUNCTION public.admin_get_tier_stats()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'free',    (SELECT COUNT(*) FROM public.profiles WHERE subscription_tier = 'free'),
    'premium', (SELECT COUNT(*) FROM public.profiles WHERE subscription_tier = 'premium'),
    'event',   (SELECT COUNT(*) FROM public.profiles WHERE subscription_tier = 'event'),
    'total',   (SELECT COUNT(*) FROM public.profiles WHERE is_active = true)
  ) INTO result;
  RETURN result;
END; $$;

-- RPC: admin set member tier
CREATE OR REPLACE FUNCTION public.admin_set_member_tier(
  p_user_id UUID, p_tier TEXT, p_notes TEXT DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_tier NOT IN ('free','premium','event') THEN RAISE EXCEPTION 'Invalid tier'; END IF;
  UPDATE public.profiles SET subscription_tier = p_tier WHERE id = p_user_id;
  INSERT INTO public.member_subscriptions (user_id, tier, status, source, notes)
  VALUES (p_user_id, p_tier, 'active', 'manual', p_notes);
END; $$;

-- RPC: admin get member subscriptions
DROP FUNCTION IF EXISTS public.admin_get_subscriptions(int, int);
CREATE OR REPLACE FUNCTION public.admin_get_subscriptions(
  p_limit INT DEFAULT 50, p_offset INT DEFAULT 0
)
RETURNS TABLE(
  user_id UUID, username TEXT, full_name TEXT, email TEXT,
  tier TEXT, status TEXT, started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ, source TEXT, notes TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
    SELECT ms.user_id, p.username, p.full_name, p.email,
           ms.tier, ms.status, ms.started_at, ms.expires_at, ms.source, ms.notes
    FROM public.member_subscriptions ms
    JOIN public.profiles p ON p.id = ms.user_id
    ORDER BY ms.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END; $$;

GRANT EXECUTE ON FUNCTION public.admin_get_tier_stats()                                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_member_tier(uuid,text,text)                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_subscriptions(int,int)                         TO authenticated;

NOTIFY pgrst, 'reload schema';


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/sm_rpc_functions.sql  [feature] owner=site-management
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════
-- Site Management RPC Functions
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── Site Pages ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_site_pages()
RETURNS SETOF public.site_pages
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.site_pages ORDER BY sort_order;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_save_site_page(
  p_path TEXT, p_visibility TEXT DEFAULT 'public',
  p_meta_title TEXT DEFAULT NULL, p_coming_soon BOOLEAN DEFAULT false
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.site_pages
  SET visibility=p_visibility, meta_title=p_meta_title, coming_soon=p_coming_soon, updated_at=now()
  WHERE path=p_path;
END; $$;

-- ── Site Features ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_site_features()
RETURNS SETOF public.site_features
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.site_features ORDER BY sort_order;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_toggle_site_feature(p_key TEXT, p_enabled BOOLEAN)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.site_features SET enabled=p_enabled WHERE key=p_key;
END; $$;

-- ── Announcements ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_announcements()
RETURNS SETOF public.site_announcements
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.site_announcements ORDER BY created_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_add_announcement(p_text TEXT, p_type TEXT DEFAULT 'info')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.site_announcements (text, type, active) VALUES (p_text, p_type, true);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_delete_announcement(p_id BIGINT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.site_announcements WHERE id=p_id;
END; $$;

-- ── Site Settings ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_site_settings()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_object_agg(key, value) INTO result FROM public.site_settings;
  RETURN COALESCE(result, '{}'::json);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_save_site_setting(p_key TEXT, p_value TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.site_settings (key, value) VALUES (p_key, p_value)
  ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now();
END; $$;

-- ── Email Templates ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_get_email_templates()
RETURNS SETOF public.email_templates
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY SELECT * FROM public.email_templates ORDER BY key;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_save_email_template(p_key TEXT, p_subject TEXT, p_body TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  INSERT INTO public.email_templates (key, subject, body) VALUES (p_key, p_subject, p_body)
  ON CONFLICT (key) DO UPDATE SET subject=EXCLUDED.subject, body=EXCLUDED.body, updated_at=now();
END; $$;

-- ── Grants ───────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.admin_get_site_pages()                             TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_site_page(text,text,text,boolean)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_site_features()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_site_feature(text,boolean)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_announcements()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_announcement(text,text)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_announcement(bigint)                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_site_settings()                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_site_setting(text,text)                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_email_templates()                        TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_save_email_template(text,text,text)          TO authenticated;

NOTIFY pgrst, 'reload schema';


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/sm_compat_rpcs.sql  [feature] owner=site-management
-- ──────────────────────────────────────────────────────────────────

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


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/fix_rls_recursion.sql  [patch] owner=core
-- ──────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════
-- Fix: infinite recursion in submitted_recipes admin policy
--
-- The policy checked profiles.is_admin via a subquery, but
-- profiles has its own RLS policies → circular evaluation.
--
-- Fix: replace the subquery with a SECURITY DEFINER function
-- that reads profiles bypassing RLS entirely.
-- ═══════════════════════════════════════════════════════════════

-- Step 2: Recreate the admin policy using the safe function
DROP POLICY IF EXISTS "admin full access to submissions" ON submitted_recipes;
CREATE POLICY "admin full access to submissions"
  ON submitted_recipes FOR ALL TO authenticated
  USING     (is_admin())
  WITH CHECK (is_admin());

-- Step 3: Verify — should return your admin status (true for Betty)
SELECT is_admin() AS am_i_admin;


-- ──────────────────────────────────────────────────────────────────
-- FILE: sql/fix_anon_grants.sql  [patch] owner=core
-- ──────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════
-- Remove anon grants from admin functions
-- Uses to_regprocedure() to match exact signatures safely
-- Returns NULL (not an error) if the signature does not exist
-- ══════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF to_regprocedure('public.admin_rename_extra_field(text, text)') IS NOT NULL THEN
    REVOKE ALL   ON FUNCTION public.admin_rename_extra_field(text, text) FROM anon;
    GRANT EXECUTE ON FUNCTION public.admin_rename_extra_field(text, text) TO authenticated;
  END IF;
END; $$;

DO $$ BEGIN
  IF to_regprocedure('public.admin_get_deleted_extra_fields()') IS NOT NULL THEN
    REVOKE ALL   ON FUNCTION public.admin_get_deleted_extra_fields() FROM anon;
    GRANT EXECUTE ON FUNCTION public.admin_get_deleted_extra_fields() TO authenticated;
  END IF;
END; $$;

DO $$ BEGIN
  IF to_regprocedure('public.admin_delete_extra_field(text)') IS NOT NULL THEN
    REVOKE ALL   ON FUNCTION public.admin_delete_extra_field(text) FROM anon;
    GRANT EXECUTE ON FUNCTION public.admin_delete_extra_field(text) TO authenticated;
  END IF;
END; $$;

SELECT 'Anon grants fixed' AS status;


-- END OF FULL SETUP
