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
-- Intentionally not recreated: admin profile reads go through SECURITY DEFINER RPCs (get_my_profile, admin_*).

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
  origin_locality     text,
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
  USING (auth.uid() = user_id AND status IN ('pending', 'rejected'))
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
